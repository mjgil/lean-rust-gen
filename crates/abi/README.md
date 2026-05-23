# lean-rust-core-abi

This crate owns the raw ABI surface: `ChStatus`, result lowering, opaque
handles, destructor policy, and panic-boundary policy. It is not part of the
default generated safe lane.

Every unsafe function requires a `# Safety` section, unit tests, and matching
FFI-boundary documentation before the corresponding feature can be marked
complete.

## Publishing safety

ABI releases are semver-major when exported C signatures, handle ownership, or
destructor contracts change. Publishing requires the dry-run commands listed in
`docs/PUBLISHING.md`.
