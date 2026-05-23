# Publishing and versioning policy

The workspace uses semver for every Rust crate. New generated functions/types are
semver-minor for the generated crate; signature, layout, ABI, or ownership
contract changes are semver-major.

Required release commands before publishing a crate:

```text
cargo publish --dry-run -p lean-rust-core-generated
cargo publish --dry-run -p lean-rust-core-runtime
cargo publish --dry-run -p lean-rust-core-abi
cargo publish --dry-run -p lean-rust-core-validate
cargo publish --dry-run -p lean-rust-core-headers
cargo doc --workspace --no-deps
cargo tree --workspace
```

Every crate must have a README, license, description, changelog entry, documented
features, and release-matrix coverage before publication.

Completion requires implementation, tests, and documentation for this feature.
