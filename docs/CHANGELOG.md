# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/). Until 1.0 the catalog schema and
module outputs may change in any minor release; such changes are listed under
**Breaking**.

## [Unreleased]

### Added

- `schema/catalog.v1.schema.json`: catalog schema version 1 (structure and
  types, strict).
- `tofu/modules/catalog`: validates and normalises a catalog; outputs `site`,
  `apps`, `instances`, `service_names`, `acme_names`, `policies`, `guests`,
  `sign_in`. Every validation rule is a precondition on an output.
- `examples/catalog`: example catalog with its expected output, one invalid
  catalog per rule.
- CI: `tofu fmt -check`, `tofu validate`, `tofu test`, schema and plan-message
  check of the example catalogs, allowlist check against customer data.
