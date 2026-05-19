# Source notes

This repo is a compact direct Lean→Rust implementation pass built from the
useful patterns in the uploaded Repomix bundles.

Copied-in concepts are small and self-contained:

- explicit lowering / checked IR / codegen seams,
- RustAdapter boundary rules for future FFI edges,
- Result lowering through status plus out-parameters,
- compatibility reports for unsupported forms.

The implementation does **not** import the original repos and does **not** keep
the previous core/app split. The app-level workflow is Lean emits Rust.
