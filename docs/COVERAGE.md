# Coverage dashboard

`rust/coverage-dashboard.json` is a generated, machine-readable dashboard. It
uses explicit denominators and explicit evidence lists so coverage claims are
derived from checked implementation artifacts rather than maintained as prose or
declaration-only feature rows.

## Evidence-derived entries

Every supported dashboard entry now includes an `evidence` object with five
required lists:

| Field | Meaning |
|---|---|
| `implementation` | Lean/Rust source files that implement the feature |
| `tests` | release-gated Rust or script checks that exercise it |
| `docs` | user-facing architecture or feature documentation |
| `generated_examples` | generated snapshots, reports, or corpus artifacts that prove the feature is emitted |
| `diagnostics` | validation-check names or stable diagnostic codes that describe the evidence path |

Task 66 is only complete when every supported feature row has all five evidence
lists populated. `LeanRustCore.ValidationV2.coverageEntries` is the canonical
source of truth, and `coverage_entries_require_evidence` proves the generated
dashboard cannot omit any required evidence category.

The final-16 release gate does more than parse the JSON. It checks that every
non-diagnostic evidence item points to an existing repo path and that each
diagnostic/code listed by the dashboard is present in the checked reports or
diagnostic documentation. If any implementation, tests, docs,
`generated_examples`, or diagnostics drift, `scripts/check-final-16-completion.py`
and `rust/tests/final16_property_coverage.rs` fail.

## Required denominators

Required denominators for the design-doc completion track:

| Denominator | Meaning | Completion requirement |
|---|---|---|
| `checklist_rows_1_20` | first twenty implementation rows | ExtractIR, runtime denotation, diagnostics, source spans, corpus fixtures, tests, and docs complete |
| `checklist_rows_41_56` | remaining checklist rows | all rows implemented with tests and docs |
| `rust_workspace_crates` | generated/runtime/ABI/validator/header crates | all crates present in Cargo workspace |
| `final_docs` | final documentation set | testing, coverage, diagnostics, crate design, release checklist, FFI docs |
| `property_seed_families` | deterministic property corpus families | every family represented in CI tests |
| `release_acceptance_gates` | required release gates | every gate scripted and documented |

## Rows 41-63 completion

The remaining completion patch adds the `checklist_rows_41_63`,
`generated_subset_semantics_heads`, and `preservation_obligations` denominators.
Each denominator is complete only when the implementation module, Rust/Lean
test, and documentation page are all present. The gate is
`scripts/check-remaining-completion.py`.
