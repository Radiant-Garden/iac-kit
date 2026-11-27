# catalog

Validates and normalises a catalog (schema version 1). Outputs only: no
resources, no providers. Every other module and the Ansible side read its
outputs, so names, keys and URLs are derived in exactly one place.

```hcl
module "catalog" {
  source  = "git::https://github.com/Radiant-Garden/iac-kit.git//tofu/modules/catalog?ref=v0.1.0"
  catalog = yamldecode(file("${path.module}/catalog.yml"))
}

# Ansible reads this with `tofu output -json catalog`.
output "catalog" {
  value = {
    site          = module.catalog.site
    apps          = module.catalog.apps
    instances     = module.catalog.instances
    service_names = module.catalog.service_names
    acme_names    = module.catalog.acme_names
    policies      = module.catalog.policies
    guests        = module.catalog.guests
    sign_in       = module.catalog.sign_in
  }
}
```

A full input and its output: [`examples/catalog/catalog.yml`](../../../examples/catalog/catalog.yml)
and [`expected.json`](../../../examples/catalog/expected.json).

## Outputs

All maps are keyed by stable names, so `for_each` addresses never depend on
order.

| Output | Key | Value |
|---|---|---|
| `site` | – | `domains.services`, `environments`, `dns`, `acme`, `identity` (each `null` when absent), `allow_from` (default `["100.64.0.0/10"]`) |
| `apps` | app | `description` (default `""`), `ports`, `access`, `role` (default: the app name), `size`, `sign_in` (defaults: `roles = {}`, `local = null`, `refresh_tokens = false`, `id_token_claims = []`), `instances` (sorted names), `aliases` |
| `instances` | instance | `name`, `app`, `env`, `host` or `guest`, `upstream`, `networks`, `compose_project` (host instances only, default: the instance name), `fqdn`, `aliases` (sorted), `hostnames` (the instance's FQDN first, then its aliases' FQDNs, sorted by alias) |
| `service_names` | FQDN | `{ type = "CNAME", name, instance, target }`. `name` is relative to `site.domains.services`. An alias's `target` is its instance's FQDN; an instance's `target` is `null`, since it points at the NetBird peer of the same name, whose DNS label only the DNS driver can look up |
| `acme_names` | FQDN | `{ name, label, target }`: `label = replace(fqdn, ".", "-")`, `target = "<label>.<site.acme.challenge_zone>"`. The only formula for challenge names: the `_acme-challenge` CNAME and Caddy's `dns_challenge_override_domain` both use `target`. Empty without `site.acme` |
| `policies` | `<app>/<proto>` | `{ name, app, sources, destination, protocol, ports }`, one per app and protocol; `name = "<access, joined by ", "> to app-<app> (<proto>)"`, `destination = "app-<app>"` |
| `guests` | instance | `{ app, platform, node, vm_id, ip, size }` for instances with `guest` |
| `sign_in` | `<app>-<env>`, `<app>-local` | `{ app, env, local, urls, redirect_uris, roles, refresh_tokens, id_token_claims }`. One registration per app with `sign_in` and environment it has instances in: `urls` are `https://<name>.<domain>` for that environment's instances, then the aliases pointing at them; `redirect_uris` = each URL × each redirect path. `<app>-local` (with `env = null`) when `sign_in.local` is set |

## Rules

Each rule is a precondition on the output named, with its own message that
names what violates it. A module without resources can't fail a plan from a
`check` block (that only warns), so the rules sit on outputs.

| Output | Rule |
|---|---|
| `site` | `schema` is 1; no unknown keys; no missing required keys; `site.environments` not empty |
| `apps` | `access` not empty; ports are `tcp/<n>` or `udp/<n>` with 1 ≤ n ≤ 65535 |
| `instances` | names are `<app>-<nn>-<env>` with `<env>` from `site.environments`; unique across apps; exactly one of `host` and `guest`; `upstream` is `<name>:<port>`, `127.0.0.1:<port>` or `unix//<path>`; `compose_project` and `networks` only on host instances; `compose_project` unique per host |
| `service_names` | an alias points at an instance of its own app; an alias equals no instance name; aliases are unique across apps; every challenge label is at most 63 characters |
| `guests` | `ip` is IPv4; `vm_id` and `ip` unique per platform |
| `sign_in` | registration names are unique (an environment called `local` would collide with `<app>-local`) |

Every rule has an invalid catalog in
[`examples/catalog/invalid/`](../../../examples/catalog/invalid/) that must
fail the plan with that rule's message.

The module is the authoritative validator. The JSON Schema
([`schema/catalog.v1.schema.json`](../../../schema/catalog.v1.schema.json))
covers structure and types for editors and pre-commit, and is strict
(`additionalProperties: false`). It does not restate cross-field rules. The
module also rejects unknown keys, because its input is `any` (an object type
would silently drop a misspelled key). A value of the wrong type (`instances`
as a list, `refresh_tokens: maybe`) fails the plan with OpenTofu's own type
error rather than a catalog message.

## How it is built

Lists first: instances, aliases, names, policies and registrations are
collected as lists, collisions are found on the lists, and maps are built with
grouping (`=> x...`). A duplicate never lets one entry silently win, as a
`merge()` would, and never stops evaluation before the precondition can
report it.
