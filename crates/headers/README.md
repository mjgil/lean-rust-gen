# lean-rust-core-headers

This crate generates C header text for the raw ABI lane. The header includes
status codes, opaque handle typedefs, destructor declarations, and ownership
annotations.

Header generation is complete only when tests verify exported signatures and
ownership comments, and when `docs/FFI_BOUNDARY.md` includes a C usage example.
