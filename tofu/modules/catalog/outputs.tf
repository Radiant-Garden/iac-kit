# The module has no resources, so its rules are preconditions on outputs: a
# `check` block would only warn. Each rule has its own message and names what
# violates it.

output "site" {
  description = "The site block with defaults applied."
  value       = local.site

  precondition {
    condition     = local.rule_schema_version
    error_message = "Catalog: `schema` must be 1."
  }
  precondition {
    condition     = length(local.rule_unknown_keys) == 0
    error_message = "Catalog: unknown keys: ${join(", ", local.rule_unknown_keys)}."
  }
  precondition {
    condition     = length(local.rule_missing_keys) == 0
    error_message = "Catalog: missing required keys: ${join(", ", local.rule_missing_keys)}."
  }
  precondition {
    condition     = local.rule_environments
    error_message = "Catalog: site.environments must list at least one environment."
  }
}

output "apps" {
  description = "Apps by name, with defaults applied and `role` resolved."
  value       = local.apps

  precondition {
    condition     = length(local.rule_empty_access) == 0
    error_message = "Catalog: access must name at least one group: ${join(", ", local.rule_empty_access)}."
  }
  precondition {
    condition     = length(local.rule_bad_ports) == 0
    error_message = "Catalog: ports must be tcp/<port> or udp/<port> with a port from 1 to 65535: ${join(", ", local.rule_bad_ports)}."
  }
}

output "instances" {
  description = "Instances by name: app, env, host or guest, upstream, networks, compose_project, fqdn, aliases, hostnames (the instance first, then its aliases)."
  value       = local.instances

  precondition {
    condition     = length(local.rule_bad_instance_names) == 0
    error_message = "Catalog: instance names must be <app>-<nn>-<env> with <env> from site.environments: ${join(", ", local.rule_bad_instance_names)}."
  }
  precondition {
    condition     = length(local.rule_duplicate_instances) == 0
    error_message = "Catalog: instance names must be unique across apps: ${join(", ", local.rule_duplicate_instances)}."
  }
  precondition {
    condition     = length(local.rule_host_xor_guest) == 0
    error_message = "Catalog: an instance needs exactly one of host and guest: ${join(", ", local.rule_host_xor_guest)}."
  }
  precondition {
    condition     = length(local.rule_bad_upstreams) == 0
    error_message = "Catalog: upstream must be <name>:<port>, 127.0.0.1:<port> or unix//<path>: ${join(", ", local.rule_bad_upstreams)}."
  }
  precondition {
    condition     = length(local.rule_guest_only_host_fields) == 0
    error_message = "Catalog: compose_project and networks apply to host instances only: ${join(", ", local.rule_guest_only_host_fields)}."
  }
  precondition {
    condition     = length(local.rule_duplicate_compose_projects) == 0
    error_message = "Catalog: compose_project must be unique per host: ${join(", ", local.rule_duplicate_compose_projects)}."
  }
}

output "service_names" {
  description = "Service names by FQDN: { type = \"CNAME\", name, instance, target }. target is null for an instance name, which points at the NetBird peer of that name."
  value       = local.service_names

  precondition {
    condition     = length(local.rule_alias_targets) == 0
    error_message = "Catalog: an alias must point at an instance of its own app: ${join(", ", local.rule_alias_targets)}."
  }
  precondition {
    condition     = length(local.rule_alias_is_instance) == 0
    error_message = "Catalog: an alias must not equal an instance name: ${join(", ", local.rule_alias_is_instance)}."
  }
  precondition {
    condition     = length(local.rule_duplicate_aliases) == 0
    error_message = "Catalog: alias names must be unique across apps: ${join(", ", local.rule_duplicate_aliases)}."
  }
  precondition {
    condition     = length(local.rule_long_labels) == 0
    error_message = "Catalog: the challenge label (the FQDN with dots replaced by dashes) must be at most 63 characters: ${join(", ", local.rule_long_labels)}."
  }
}

output "acme_names" {
  description = "Challenge names by FQDN: { name, label, target }. target = <label>.<challenge zone>, label = the FQDN with dots replaced by dashes. Empty without site.acme."
  value       = local.acme_names
}

output "policies" {
  description = "NetBird policies by <app>/<protocol>: { name, app, sources, destination, protocol, ports }."
  value       = local.policies
}

output "guests" {
  description = "Placement of guest instances by instance name: { app, platform, node, vm_id, ip, size }."
  value       = local.guests

  precondition {
    condition     = length(local.rule_bad_ips) == 0
    error_message = "Catalog: guest.ip must be an IPv4 address: ${join(", ", local.rule_bad_ips)}."
  }
  precondition {
    condition     = length(local.rule_duplicate_vm_ids) == 0
    error_message = "Catalog: vm_id must be unique per platform: ${join(", ", local.rule_duplicate_vm_ids)}."
  }
  precondition {
    condition     = length(local.rule_duplicate_ips) == 0
    error_message = "Catalog: guest.ip must be unique per platform: ${join(", ", local.rule_duplicate_ips)}."
  }
}

output "sign_in" {
  description = "Sign-in registrations by <app>-<env> and <app>-local: { app, env, local, urls, redirect_uris, roles, refresh_tokens, id_token_claims }."
  value       = local.sign_in

  precondition {
    condition     = length(local.rule_duplicate_registrations) == 0
    error_message = "Catalog: sign-in registration names must be unique: ${join(", ", local.rule_duplicate_registrations)}."
  }
}
