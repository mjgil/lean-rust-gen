# Preservation skeleton

The current proof skeleton records the preservation seams that must hold for the
direct backend:

| Seam | Owner | Tests |
|---|---|---|
| extraction | `LeanRustCore.ExtractIR` | first-20 completion tests |
| erasure | `LeanRustCore.DependentErasureChecker` | next-20 completion tests |
| Surface typing | `LeanRustCore.Surface.typeOfExpected` | differential tests |
| Surface evaluation | `LeanRustCore.Surface.evalSurfaceFun` | differential tests |
| target fingerprints | `LeanRustCore.TargetValidation` | semantic validation tests |
| Rust AST validation | parser validation tests | parser tests |
| target semantics | `LeanRustCore.CompleteSemantics` | validator crate tests |

A seam is complete only when it has an implementation owner, tests, and docs.
The skeleton is intentionally designed so deeper formal lemmas can replace
metadata obligations without changing the release gate shape.
