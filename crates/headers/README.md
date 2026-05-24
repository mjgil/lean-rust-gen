# lean-rust-core-headers

This crate generates C header text for the raw ABI lane. The header includes
status codes, opaque handle typedefs, destructor declarations, and ownership
annotations.

Header generation is complete only when tests verify exported signatures and
ownership comments, and when `docs/FFI_BOUNDARY.md` includes a C usage example.

## Release policy

Header output is tested as part of the workspace release matrix and versioned
with the ABI crate. Signature changes require changelog entries and semver-major
review.

The publishing gate is `scripts/check-publishing.sh`, which checks manifest
metadata, docs builds, dependency/license audit, and
`cargo publish --dry-run -p lean-rust-core-headers`.

Reference docs: <https://docs.rs/lean-rust-core-headers>
