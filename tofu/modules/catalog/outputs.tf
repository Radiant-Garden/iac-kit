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
  precondition {
    condition     = length(local.rule_null_entries) == 0
    error_message = "Catalog: list entries must not be empty (null): ${join(", ", local.rule_null_entries)}."
  }
  precondition {
    condition     = length(local.rule_bad_environment_names) == 0
    error_message = "Catalog: environment names must be lowercase letters and digits, starting with a letter: ${join(", ", local.rule_bad_environment_names)}."
  }
  precondition {
    condition     = length(local.rule_unsupported_providers) == 0
    error_message = "Catalog: unsupported provider: ${join(", ", local.rule_unsupported_providers)}."
  }
  precondition {
    condition     = local.rule_bad_role_namespace
    error_message = "Catalog: site.identity.role_namespace must be an https:// URL without a trailing slash (app-role IDs are derived from it)."
  }
}

output "apps" {
  description = "Apps by name, with defaults applied, `role` resolved and `group` (app-<app>) added."
  value       = local.apps

  precondition {
    condition     = length(local.rule_empty_access) == 0
    error_message = "Catalog: access must name at least one group: ${join(", ", local.rule_empty_access)}."
  }
  precondition {
    condition     = length(local.rule_bad_ports) == 0
    error_message = "Catalog: ports must be tcp/<port> or udp/<port> with a port from 1 to 65535: ${join(", ", local.rule_bad_ports)}."
  }
  precondition {
    condition     = length(local.rule_bad_app_names) == 0
    error_message = "Catalog: app names must be DNS labels (lowercase letters, digits, single dashes, starting with a letter): ${join(", ", local.rule_bad_app_names)}."
  }
  precondition {
    condition     = length(local.rule_empty_ports) == 0
    error_message = "Catalog: ports must list at least one port: ${join(", ", local.rule_empty_ports)}."
  }
  precondition {
    condition     = length(local.rule_repeated_entries) == 0
    error_message = "Catalog: ports and access must not repeat an entry: ${join(", ", local.rule_repeated_entries)}."
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
  precondition {
    condition     = length(local.rule_not_maps) == 0
    error_message = "Catalog: instances and aliases must be maps (catalog v1; v0 listed instances): ${join(", ", local.rule_not_maps)}."
  }
  precondition {
    condition     = length(local.rule_upstream_without_acme) == 0
    error_message = "Catalog: an instance with an upstream needs site.acme (certificates are always delegated): ${join(", ", local.rule_upstream_without_acme)}."
  }
  precondition {
    condition     = length(local.rule_bad_compose_projects) == 0
    error_message = "Catalog: compose_project must be lowercase letters, digits, - and _: ${join(", ", local.rule_bad_compose_projects)}."
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
  precondition {
    condition     = length(local.rule_bad_alias_names) == 0
    error_message = "Catalog: alias names must be DNS labels (lowercase letters, digits, dashes): ${join(", ", local.rule_bad_alias_names)}."
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
  precondition {
    condition     = length(local.rule_unsupported_platforms) == 0
    error_message = "Catalog: unsupported guest.platform: ${join(", ", local.rule_unsupported_platforms)}."
  }
  precondition {
    condition     = length(local.rule_bad_vm_ids) == 0
    error_message = "Catalog: vm_id must be an integer of at least 100: ${join(", ", local.rule_bad_vm_ids)}."
  }
}

output "sign_in" {
  description = "Sign-in registrations by <app>-<env> and <app>-local: { app, env, local, urls, redirect_uris, roles, refresh_tokens, id_token_claims }."
  value       = local.sign_in

  precondition {
    condition     = length(local.rule_duplicate_registrations) == 0
    error_message = "Catalog: sign-in registration names must be unique: ${join(", ", local.rule_duplicate_registrations)}."
  }
  precondition {
    condition     = length(local.rule_sign_in_without_identity) == 0
    error_message = "Catalog: sign_in needs site.identity: ${join(", ", local.rule_sign_in_without_identity)}."
  }
  precondition {
    condition     = length(local.rule_bad_redirect_paths) == 0
    error_message = "Catalog: redirect_paths must list at least one path, each starting with /: ${join(", ", local.rule_bad_redirect_paths)}."
  }
}
