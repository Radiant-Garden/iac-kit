# Normalises a catalog (schema version 1) into maps keyed by stable names.
#
# Everything is built as a list first. Collisions are found on those lists
# (see the rule_* locals) and reported by the preconditions in outputs.tf;
# maps are only built with grouping (`=> x...`), so a duplicate key never
# lets one entry silently win and never crashes evaluation before the
# precondition can name it.
#
# Conversions (tostring, tolist, ...) sit outside try(): try() only covers a
# missing key, so a value of the wrong type fails loudly instead of falling
# back to a default. A null where a value is required (`aliases: { wiki: }`,
# `ports: [~]`) becomes "<null>" inside the rules, so the rule that owns it
# reports it instead of a string template failing first.

locals {
  raw      = var.catalog
  raw_site = try(local.raw.site, null)
  raw_apps = try(local.raw.apps, null)
  null_s   = "<null>"

  # ── Structure ──────────────────────────────────────────────────────────────

  allowed_keys = {
    catalog  = ["schema", "site", "apps"]
    site     = ["domains", "environments", "dns", "acme", "allow_from", "identity"]
    domains  = ["services"]
    dns      = ["provider", "distribution_groups"]
    acme     = ["provider", "challenge_zone"]
    identity = ["provider", "role_namespace"]
    app      = ["description", "ports", "access", "role", "size", "sign_in", "instances", "aliases"]
    size     = ["cores", "memory", "disk"]
    sign_in  = ["redirect_paths", "roles", "local", "refresh_tokens", "id_token_claims"]
    instance = ["host", "guest", "upstream", "networks", "compose_project"]
    guest    = ["platform", "node", "vm_id", "ip"]
  }

  required_keys = {
    catalog  = ["schema", "site", "apps"]
    site     = ["domains", "environments"]
    domains  = ["services"]
    dns      = ["provider"]
    acme     = ["provider", "challenge_zone"]
    identity = ["provider", "role_namespace"]
    app      = ["ports", "access"]
    size     = ["cores", "memory", "disk"]
    sign_in  = ["redirect_paths"]
    guest    = ["platform", "node", "vm_id", "ip"]
  }

  supported = {
    dns      = ["netbird-zone", "powerdns"]
    acme     = ["hetzner"]
    identity = ["entra"]
    platform = ["proxmox-lxc"]
  }

  app_names = local.raw_apps == null ? [] : sort(keys(local.raw_apps))

  # instances and aliases are maps in v1 (v0 had a list of instances). Not a
  # map → no names here, and rule_not_maps says why.
  app_instance_names = {
    for app in local.app_names : app =>
    can(keys(local.raw_apps[app].instances)) ? sort(keys(local.raw_apps[app].instances)) : []
  }
  app_alias_names = {
    for app in local.app_names : app =>
    can(keys(local.raw_apps[app].aliases)) ? sort(keys(local.raw_apps[app].aliases)) : []
  }
  rule_not_maps = flatten([
    for app in local.app_names : [
      for k in ["instances", "aliases"] : "apps.${app}.${k}"
      if try(local.raw_apps[app][k], null) != null && !can(keys(local.raw_apps[app][k]))
    ]
  ])

  # Every object in the catalog with its path and kind, to check keys once.
  objects = concat(
    [{ path = "catalog", kind = "catalog", value = local.raw }],
    [{ path = "site", kind = "site", value = local.raw_site }],
    [for k in ["domains", "dns", "acme", "identity"] : { path = "site.${k}", kind = k, value = try(local.raw_site[k], null) }],
    flatten([
      for app in local.app_names : concat(
        [{ path = "apps.${app}", kind = "app", value = local.raw_apps[app] }],
        [{ path = "apps.${app}.size", kind = "size", value = try(local.raw_apps[app].size, null) }],
        [{ path = "apps.${app}.sign_in", kind = "sign_in", value = try(local.raw_apps[app].sign_in, null) }],
        flatten([
          for i in local.app_instance_names[app] : [
            { path = "apps.${app}.instances.${i}", kind = "instance", value = local.raw_apps[app].instances[i] },
            { path = "apps.${app}.instances.${i}.guest", kind = "guest", value = try(local.raw_apps[app].instances[i].guest, null) },
          ]
        ]),
      )
    ]),
  )

  # Optional blocks that are absent are skipped; an instance written as a
  # bare key (value null) still counts, so it is reported as lacking host/guest.
  present_objects = [for o in local.objects : o if o.value != null || o.kind == "instance"]

  rule_unknown_keys = flatten([
    for o in local.present_objects : [
      for k in try(keys(o.value), []) : "${o.path}.${k}" if !contains(local.allowed_keys[o.kind], k)
    ]
  ])
  rule_missing_keys = flatten([
    for o in local.present_objects : [
      for k in lookup(local.required_keys, o.kind, []) : "${o.path}.${k}" if try(o.value[k], null) == null
    ]
  ])
  rule_schema_version = try(local.raw.schema, null) == 1

  # Lists of strings whose entries must not be null.
  raw_lists = concat(
    [for k in ["environments", "allow_from"] : { path = "site.${k}", value = try(local.raw_site[k], null) }],
    [{ path = "site.dns.distribution_groups", value = try(local.raw_site.dns.distribution_groups, null) }],
    flatten([
      for app in local.app_names : concat(
        [for k in ["ports", "access"] : { path = "apps.${app}.${k}", value = try(local.raw_apps[app][k], null) }],
        [for k in ["redirect_paths", "id_token_claims"] : { path = "apps.${app}.sign_in.${k}", value = try(local.raw_apps[app].sign_in[k], null) }],
        [for i in local.app_instance_names[app] : { path = "apps.${app}.instances.${i}.networks", value = try(local.raw_apps[app].instances[i].networks, null) }],
      )
    ]),
  )
  rule_null_entries = [
    for l in local.raw_lists : l.path
    if l.value != null && length([for x in try(tolist(l.value), []) : x if x == null]) > 0
  ]

  # ── Site ───────────────────────────────────────────────────────────────────

  domain       = try(local.raw_site.domains.services, null) == null ? null : tostring(local.raw_site.domains.services)
  environments = try(local.raw_site.environments, null) == null ? [] : [for e in tolist(local.raw_site.environments) : e == null ? local.null_s : tostring(e)]

  site = {
    domains      = { services = local.domain }
    environments = local.environments
    dns = try(local.raw_site.dns, null) == null ? null : {
      provider            = tostring(try(local.raw_site.dns.provider, null))
      distribution_groups = try(local.raw_site.dns.distribution_groups, null) == null ? [] : tolist(local.raw_site.dns.distribution_groups)
    }
    acme = try(local.raw_site.acme, null) == null ? null : {
      provider       = tostring(try(local.raw_site.acme.provider, null))
      challenge_zone = tostring(try(local.raw_site.acme.challenge_zone, null))
    }
    # Today's only value: the NetBird range (RFC 6598).
    allow_from = try(local.raw_site.allow_from, null) == null ? ["100.64.0.0/10"] : tolist(local.raw_site.allow_from)
    identity = try(local.raw_site.identity, null) == null ? null : {
      provider       = tostring(try(local.raw_site.identity.provider, null))
      role_namespace = tostring(try(local.raw_site.identity.role_namespace, null))
    }
  }

  rule_environments = length(local.environments) > 0

  rule_bad_environment_names = [for e in local.environments : e if !can(regex("^[a-z][a-z0-9]*$", e))]

  rule_unsupported_providers = [
    for k in ["dns", "acme", "identity"] :
    "site.${k}.provider = ${coalesce(try(local.site[k].provider, null), local.null_s)} (supported: ${join(", ", local.supported[k])})"
    if local.site[k] != null && !contains(local.supported[k], coalesce(try(local.site[k].provider, null), local.null_s))
  ]

  # App-role IDs are derived from this string; a trailing slash would change
  # every one of them.
  rule_bad_role_namespace = local.site.identity == null ? true : can(regex("^https://\\S*[^/]$", coalesce(local.site.identity.role_namespace, local.null_s)))

  # A missing domain is reported as a missing key; the placeholder only keeps
  # the string templates below from failing before that message is shown.
  fqdn_suffix = local.domain == null ? "invalid" : local.domain

  # ── Apps ───────────────────────────────────────────────────────────────────

  port_regex = "^(tcp|udp)/[1-9][0-9]{0,4}$"

  apps = {
    for app in local.app_names : app => {
      description = try(local.raw_apps[app].description, null) == null ? "" : tostring(local.raw_apps[app].description)
      ports       = try(local.raw_apps[app].ports, null) == null ? [] : [for p in tolist(local.raw_apps[app].ports) : p == null ? local.null_s : tostring(p)]
      access      = try(local.raw_apps[app].access, null) == null ? [] : [for g in tolist(local.raw_apps[app].access) : g == null ? local.null_s : tostring(g)]
      role        = try(local.raw_apps[app].role, null) == null ? app : tostring(local.raw_apps[app].role)
      group       = "app-${app}"
      size = try(local.raw_apps[app].size, null) == null ? null : {
        cores  = tonumber(try(local.raw_apps[app].size.cores, null))
        memory = tonumber(try(local.raw_apps[app].size.memory, null))
        disk   = tonumber(try(local.raw_apps[app].size.disk, null))
      }
      sign_in = try(local.raw_apps[app].sign_in, null) == null ? null : {
        redirect_paths = try(local.raw_apps[app].sign_in.redirect_paths, null) == null ? [] : [for p in tolist(local.raw_apps[app].sign_in.redirect_paths) : p == null ? local.null_s : tostring(p)]
        roles = {
          for v in(can(keys(local.raw_apps[app].sign_in.roles)) ? sort(keys(local.raw_apps[app].sign_in.roles)) : []) :
          v => tostring(local.raw_apps[app].sign_in.roles[v])
        }
        local           = try(local.raw_apps[app].sign_in.local, null) == null ? null : tostring(local.raw_apps[app].sign_in.local)
        refresh_tokens  = try(local.raw_apps[app].sign_in.refresh_tokens, null) == null ? false : tobool(local.raw_apps[app].sign_in.refresh_tokens)
        id_token_claims = try(local.raw_apps[app].sign_in.id_token_claims, null) == null ? [] : [for c in tolist(local.raw_apps[app].sign_in.id_token_claims) : c == null ? local.null_s : tostring(c)]
      }
      instances = local.app_instance_names[app]
      aliases = {
        for a in local.app_alias_names[app] : a =>
        local.raw_apps[app].aliases[a] == null ? local.null_s : tostring(local.raw_apps[app].aliases[a])
      }
    }
  }

  rule_bad_app_names = [for app in local.app_names : app if !can(regex("^[a-z][a-z0-9]*(-[a-z0-9]+)*$", app))]

  # Absent keys are reported as missing; these catch present but empty lists.
  rule_empty_access = [for app in local.app_names : app if try(local.raw_apps[app].access, null) != null && length(local.apps[app].access) == 0]
  rule_empty_ports  = [for app in local.app_names : app if try(local.raw_apps[app].ports, null) != null && length(local.apps[app].ports) == 0]

  rule_bad_ports = flatten([
    for app in local.app_names : [
      for p in local.apps[app].ports : "${app}: ${p}"
      if !can(regex(local.port_regex, p)) || try(tonumber(split("/", p)[1]) > 65535, true)
    ]
  ])

  rule_repeated_entries = [
    for app in local.app_names : app
    if length(distinct(local.apps[app].ports)) != length(local.apps[app].ports) ||
    length(distinct(local.apps[app].access)) != length(local.apps[app].access)
  ]

  # ── Instances ──────────────────────────────────────────────────────────────

  instance_regex = {
    for app in local.app_names : app => "^${app}-[0-9]{2}-(${join("|", local.environments)})$"
  }

  instance_list = flatten([
    for app in local.app_names : [
      for name in local.app_instance_names[app] : {
        name = name
        app  = app
        # Valid app and environment names contain no regex metacharacters;
        # invalid ones are reported by their own rules.
        env  = try(regex(local.instance_regex[app], name)[0], null)
        host = tostring(try(local.raw_apps[app].instances[name].host, null))
        guest = try(local.raw_apps[app].instances[name].guest, null) == null ? null : {
          platform = tostring(try(local.raw_apps[app].instances[name].guest.platform, null))
          node     = tostring(try(local.raw_apps[app].instances[name].guest.node, null))
          vm_id    = tonumber(try(local.raw_apps[app].instances[name].guest.vm_id, null))
          ip       = tostring(try(local.raw_apps[app].instances[name].guest.ip, null))
        }
        upstream        = tostring(try(local.raw_apps[app].instances[name].upstream, null))
        networks        = try(local.raw_apps[app].instances[name].networks, null) == null ? [] : [for n in tolist(local.raw_apps[app].instances[name].networks) : n == null ? local.null_s : tostring(n)]
        compose_project = tostring(try(local.raw_apps[app].instances[name].compose_project, null))
      }
    ]
  ])

  instance_names = [for i in local.instance_list : i.name]

  alias_list = flatten([
    for app in local.app_names : [
      for a in local.app_alias_names[app] : {
        alias    = a
        app      = app
        instance = local.apps[app].aliases[a]
      }
    ]
  ])

  instance_rows = [
    for i in local.instance_list : {
      name     = i.name
      app      = i.app
      env      = i.env
      host     = i.host
      guest    = i.guest
      upstream = i.upstream
      networks = i.networks
      # Default = the instance name, so two instances of one app can share a
      # host. Only host instances have a Compose project.
      compose_project = i.host == null ? null : (i.compose_project == null ? i.name : i.compose_project)
      fqdn            = "${i.name}.${local.fqdn_suffix}"
      aliases         = [for a in local.alias_list : a.alias if a.instance == i.name && a.app == i.app]
      hostnames = concat(
        ["${i.name}.${local.fqdn_suffix}"],
        [for a in local.alias_list : "${a.alias}.${local.fqdn_suffix}" if a.instance == i.name && a.app == i.app],
      )
    }
  ]

  instances = {
    for name, g in { for i in local.instance_rows : i.name => i... } : name => g[0]
  }

  rule_bad_instance_names = [for i in local.instance_list : "${i.app}: ${i.name}" if i.env == null]

  rule_duplicate_instances = [
    for name, g in { for i in local.instance_list : i.name => i.app... } : "${name} (${join(", ", g)})" if length(g) > 1
  ]

  # An empty host counts as no host.
  rule_host_xor_guest = [for i in local.instance_list : i.name if(i.host == null || i.host == "") == (i.guest == null)]

  upstream_regex = "^(([a-z0-9]([a-z0-9_-]*[a-z0-9])?)|127\\.0\\.0\\.1):([0-9]{1,5})$"
  rule_bad_upstreams = [
    for i in local.instance_list : "${i.name}: ${i.upstream}"
    if i.upstream != null && !(
      can(regex("^unix//\\S+$", i.upstream)) ||
      try(tonumber(regex(local.upstream_regex, i.upstream)[3]) >= 1 && tonumber(regex(local.upstream_regex, i.upstream)[3]) <= 65535, false)
    )
  ]

  # §4.3: ACME is always delegated, so Caddy (an upstream) needs site.acme.
  rule_upstream_without_acme = local.site.acme != null ? [] : [for i in local.instance_list : i.name if i.upstream != null]

  rule_guest_only_host_fields = [
    for i in local.instance_list : i.name
    if i.guest != null && (i.compose_project != null || length(i.networks) > 0)
  ]

  rule_bad_compose_projects = [
    for i in local.instance_list : "${i.name}: \"${i.compose_project}\""
    if i.compose_project != null && !can(regex("^[a-z0-9][a-z0-9_-]*$", i.compose_project))
  ]

  rule_duplicate_compose_projects = [
    for k, g in { for i in local.instance_rows : "${i.host}/${i.compose_project}" => i.name... if i.host != null } :
    "${k} (${join(", ", g)})" if length(g) > 1
  ]

  # ── Aliases and names ──────────────────────────────────────────────────────

  rule_bad_alias_names = [for a in local.alias_list : "${a.app}: ${a.alias}" if !can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", a.alias))]

  rule_alias_targets = [
    for a in local.alias_list : "${a.app}: ${a.alias} -> ${a.instance}"
    if !contains(local.app_instance_names[a.app], a.instance)
  ]

  rule_alias_is_instance = [for a in local.alias_list : "${a.app}: ${a.alias}" if contains(local.instance_names, a.alias)]

  rule_duplicate_aliases = [
    for alias, g in { for a in local.alias_list : a.alias => a.app... } : "${alias} (${join(", ", g)})" if length(g) > 1
  ]

  name_rows = concat(
    [for i in local.instance_list : { name = i.name, instance = i.name, target = null }],
    [for a in local.alias_list : { name = a.alias, instance = a.instance, target = "${a.instance}.${local.fqdn_suffix}" }],
  )

  # Instance names have no target here: they point at the NetBird peer of the
  # same name, whose DNS label only the DNS driver can look up.
  service_names = {
    for fqdn, g in { for r in local.name_rows : "${r.name}.${local.fqdn_suffix}" => r... } : fqdn => {
      type     = "CNAME"
      name     = g[0].name
      instance = g[0].instance
      target   = g[0].target
    }
  }

  # The only formula for challenge names: Caddy's dns_challenge_override_domain
  # and the _acme-challenge CNAME both take `target` from here. With app,
  # alias and environment names restricted to DNS labels (no dots), distinct
  # names always give distinct labels.
  acme_names = local.site.acme == null ? {} : {
    for fqdn, s in local.service_names : fqdn => {
      name   = s.name
      label  = replace(fqdn, ".", "-")
      target = "${replace(fqdn, ".", "-")}.${coalesce(local.site.acme.challenge_zone, local.null_s)}"
    }
  }

  rule_long_labels = [
    for r in local.name_rows : "${r.name}.${local.fqdn_suffix}"
    if length(replace("${r.name}.${local.fqdn_suffix}", ".", "-")) > 63
  ]

  # ── Policies ───────────────────────────────────────────────────────────────

  # One policy per app and protocol (the NetBird provider allows one rule per
  # policy). The name always carries the protocol, so adding one never renames.
  policy_rows = flatten([
    for app in local.app_names : [
      for proto in distinct([for p in local.apps[app].ports : split("/", p)[0] if can(regex(local.port_regex, p))]) : {
        key         = "${app}/${proto}"
        name        = "${join(", ", local.apps[app].access)} to ${local.apps[app].group} (${proto})"
        app         = app
        sources     = local.apps[app].access
        destination = local.apps[app].group
        protocol    = proto
        ports       = [for p in local.apps[app].ports : split("/", p)[1] if can(regex(local.port_regex, p)) && split("/", p)[0] == proto]
      }
    ]
  ])

  policies = {
    for k, g in { for p in local.policy_rows : p.key => p... } : k => {
      name        = g[0].name
      app         = g[0].app
      sources     = g[0].sources
      destination = g[0].destination
      protocol    = g[0].protocol
      ports       = g[0].ports
    }
  }

  # ── Guests ─────────────────────────────────────────────────────────────────

  guest_rows = [
    for i in local.instance_list : {
      name     = i.name
      app      = i.app
      platform = coalesce(i.guest.platform, local.null_s)
      vm_id    = i.guest.vm_id
      vm_id_s  = coalesce(tostring(i.guest.vm_id), local.null_s)
      ip       = coalesce(i.guest.ip, local.null_s)
    } if i.guest != null
  ]

  guests = {
    for name, g in { for i in local.instance_list : i.name => i... if i.guest != null } : name => {
      app      = g[0].app
      platform = g[0].guest.platform
      node     = g[0].guest.node
      vm_id    = g[0].guest.vm_id
      ip       = g[0].guest.ip
      size     = local.apps[g[0].app].size
    }
  }

  rule_unsupported_platforms = [
    for g in local.guest_rows : "${g.name}: ${g.platform} (supported: ${join(", ", local.supported.platform)})"
    if !contains(local.supported.platform, g.platform)
  ]
  rule_bad_vm_ids = [
    for g in local.guest_rows : "${g.name}: ${g.vm_id_s}"
    if !try(g.vm_id >= 100 && floor(g.vm_id) == g.vm_id, false)
  ]
  rule_duplicate_vm_ids = [
    for k, g in { for r in local.guest_rows : "${r.platform}/${r.vm_id_s}" => r.name... } :
    "${k} (${join(", ", g)})" if length(g) > 1
  ]
  rule_duplicate_ips = [
    for k, g in { for r in local.guest_rows : "${r.platform}/${r.ip}" => r.name... } :
    "${k} (${join(", ", g)})" if length(g) > 1
  ]
  rule_bad_ips = [
    for g in local.guest_rows : "${g.name}: ${g.ip}"
    if !can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", g.ip)) || !can(cidrhost("${g.ip}/32", 0))
  ]

  # ── Sign-in ────────────────────────────────────────────────────────────────

  # One registration per app and environment with every name of that
  # environment's instances and the aliases pointing at them, plus
  # <app>-local when sign_in.local is set.
  sign_in_rows = concat(
    flatten([
      for app in local.app_names : [
        for env in distinct([for i in local.instance_list : i.env if i.app == app && i.env != null]) : {
          key   = "${app}-${env}"
          app   = app
          env   = env
          local = false
          urls = [
            for n in concat(
              [for i in local.instance_list : i.name if i.app == app && i.env == env],
              [for a in local.alias_list : a.alias if a.app == app && try(local.instances[a.instance].env, null) == env],
            ) : "https://${n}.${local.fqdn_suffix}"
          ]
        }
      ] if local.apps[app].sign_in != null
    ]),
    [
      for app in local.app_names : {
        key   = "${app}-local"
        app   = app
        env   = null
        local = true
        urls  = [local.apps[app].sign_in.local]
      } if local.apps[app].sign_in != null && try(local.apps[app].sign_in.local, null) != null
    ],
  )

  sign_in = {
    for k, g in { for r in local.sign_in_rows : r.key => r... } : k => {
      app             = g[0].app
      env             = g[0].env
      local           = g[0].local
      urls            = g[0].urls
      redirect_uris   = flatten([for u in g[0].urls : [for p in local.apps[g[0].app].sign_in.redirect_paths : "${u}${p}"]])
      roles           = local.apps[g[0].app].sign_in.roles
      refresh_tokens  = local.apps[g[0].app].sign_in.refresh_tokens
      id_token_claims = local.apps[g[0].app].sign_in.id_token_claims
    }
  }

  sign_in_apps = [for app in local.app_names : app if local.apps[app].sign_in != null]

  rule_sign_in_without_identity = local.site.identity != null ? [] : local.sign_in_apps

  rule_bad_redirect_paths = flatten([
    for app in local.sign_in_apps : concat(
      length(local.apps[app].sign_in.redirect_paths) == 0 ? ["${app}: (none)"] : [],
      [for p in local.apps[app].sign_in.redirect_paths : "${app}: ${p}" if !startswith(p, "/")],
    )
  ])

  rule_duplicate_registrations = [
    for k, g in { for r in local.sign_in_rows : r.key => r.app... } : "${k} (${join(", ", g)})" if length(g) > 1
  ]
}
