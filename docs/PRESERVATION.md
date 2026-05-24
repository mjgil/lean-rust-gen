# Preservation lemmas

The direct backend now carries representative proved Lean theorems for the main
preservation seams instead of only recording seam owners.

| Seam | Theorem | What it proves |
|---|---|---|
| extraction | `extraction_metadata_preserved` | Supported `ExtractIR` metadata keeps source name, Rust name, and admitted feature tags for a representative extracted declaration. |
| erasure | `dependent_erasure_runtime_carriers_preserved` | `Subtype`, `Fin`, `Vector`, and equality-cast fixtures preserve the admitted runtime carrier/check contract. |
| Surface typing | `checked_surface_typing_preserved` | `Surface.checkSurfaceFun` preserves the declared result type for a representative extracted function. |
| Surface evaluation | `checked_surface_evaluation_preserved` | `Surface.evalSurfaceFun` preserves the representative computed result used by the differential suite. |
| target lowering | `target_lowering_snapshot_preserved` | target-validation v2 preserves representative lowered enum/function fingerprints and module counts. |
| safe-subset emission | `safe_subset_emission_preserved` | the direct emitted Rust lane excludes unsafe/raw-ABI/mutable-reference/explicit-lifetime forms. |
| emitted-subset semantics | `emitted_subset_target_semantics_preserved` | representative struct, closure, dictionary, effect, and recursive target terms evaluate as documented. |

## Implementation requirements

`LeanRustCore.Preservation` must keep executable boolean checks and theorem names
for every seam above. The remaining-completion gate and Rust tests now scan the
Lean source for those theorem names, so deleting a theorem or reducing the file
back to seam metadata alone fails release validation.

## Tests required before completion

`scripts/check-remaining-completion.py`, `rust/tests/remaining_completion.rs`,
and the full `./scripts/check.sh` path must all pass. The Lean build itself is
also part of the proof gate because `preservation_lemmas_completion_gate`
references every seam theorem directly.

## Documentation required before completion

This document must list the proved theorems explicitly, and
`docs/TRUSTED_CORE.md` must distinguish proved preservation lemmas from
regression-tested facts that remain outside the Lean proof boundary.
