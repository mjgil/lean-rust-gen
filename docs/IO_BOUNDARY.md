# Controlled IO boundary

The default generated Rust lane is pure. Controlled IO is represented explicitly
as a boundary program and transcript so that tests remain deterministic.

Whitelisted operations:

| Operation | Rust shape | Deterministic test |
|---|---|---|
| print line | append `print:<line>` to transcript | `controlled_io_boundary_is_transcript_based` |
| read env | append `read-env:<key>` to transcript, using supplied environment inputs only | runtime test |
| monotonic time | append supplied deterministic timestamp | runtime test |

Arbitrary `IO`, `EIO`, `Task`, ambient process environment reads, mutation, and
external effects are rejected by diagnostics unless a future effect-specific
boundary admits them with tests and safety documentation.

Completion requires implementation, tests, and documentation for this feature.
