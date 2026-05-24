# Changelog

## Unreleased

- Productionized workspace publishing/versioning checks with manifest metadata,
  dependency/license audit, changelog validation, docs build verification, and
  per-crate `cargo publish --dry-run` release gating.
- Removed tracked local artifacts from the public release surface, added
  explicit open-source hygiene checks, and replaced the placeholder repository
  license file with full Apache-2.0 and MIT license texts.

## 0.2.0

- Completed checklist rows 1-63 for the large-subset design track.
- Added generated typeclass dictionaries, first-class closure objects, pure
do-notation metadata, controlled IO boundary metadata, complete generated-subset
semantics, preservation skeleton, property generators, feature-complete coverage,
CI release matrix metadata, and publishing/versioning policy.
- Kept the default generated Rust lane safe and the raw ABI lane feature-gated.
