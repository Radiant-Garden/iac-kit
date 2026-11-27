# iac-kit

Reusable OpenTofu modules and a catalog schema for running internal services
behind NetBird: one catalog describes the apps, their instances and where they
run, and everything else (NetBird groups and policies, DNS names, ACME
delegation, sign-in registrations) is derived from it in OpenTofu. Ansible
reads the same derived model with `tofu output -json catalog`, so there is no
second implementation that could drift.

Customer repositories **reference** the kit by a pinned tag; they never fork it.

## What is here

```
schema/catalog.v1.schema.json   structure and types of catalog.yml
tofu/modules/catalog/           validates and normalises the catalog (outputs only)
examples/catalog/               an example catalog, its expected output, invalid catalogs
ci/                             checks run by CI (and locally)
docs/CHANGELOG.md
```

More modules and an Ansible collection follow as they are needed. Nothing is
added before a second repository is about to use it.

## The catalog

An **app** says what is offered and to whom; an **instance** says where it
runs: on a shared `host` (the sidecar runs as containers in the app's Compose
project) or as its own `guest` (VM or container, sidecar native). Caddy runs
in front of an instance if and only if it has an `upstream`.

```yaml
schema: 1
site:
  domains: { services: svc.example.org }
  environments: [prod, dev]
  acme: { provider: hetzner, challenge_zone: acme.example.com }
apps:
  wiki:
    description: Team wiki
    ports: [tcp/443]
    access: [staff]
    instances:
      wiki-01-prod: { host: apps-01, upstream: wiki:8080 }
    aliases: { wiki: wiki-01-prod }
```

The full example is [`examples/catalog/catalog.yml`](examples/catalog/catalog.yml);
the outputs, their keys and the validation rules are described in
[`tofu/modules/catalog/README.md`](tofu/modules/catalog/README.md). Editors
pick up the schema from the first line of the example
(`# yaml-language-server: $schema=...`).

The schema is unstable until v1.0.

## Requirements

OpenTofu ≥ 1.11.

## Development

```sh
tofu fmt -check -recursive
ci/validate.sh                                   # tofu validate, every module and example
tofu -chdir=tofu/modules/catalog init -backend=false
tofu -chdir=tofu/modules/catalog test            # output = expected.json, invalid catalogs fail
CHECK_JSONSCHEMA="pipx run check-jsonschema==0.33.0" ci/check-examples.sh
python3 ci/allowlist-check.py                    # no names or addresses outside ci/allowlist.txt
```

`ci/check-examples.sh` plans every catalog in `examples/catalog/invalid/` and
checks the message from its `# expect-error:` header, whether the JSON Schema
accepts it (`# schema:`), and that `tofu test` has a run for it.

### No customer data

This repository is public. Examples use `example.org` / `example.com` and the
documentation address ranges (RFC 5737, RFC 6598) only. CI enforces an
allowlist (`ci/allowlist.txt`, `ci/allowlist-check.py`): every IP literal and
every name under a real TLD must be allowed, or the check fails. Add vendor
hosts to the allowlist; never add anything that names a customer.

Changes go through a pull request with green CI.

## License

Apache-2.0, see [LICENSE](LICENSE).
