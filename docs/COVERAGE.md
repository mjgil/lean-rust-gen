# Coverage dashboard

`rust/coverage-dashboard.json` is a generated, machine-readable dashboard. It
uses explicit denominators so coverage claims are auditable rather than prose.

Required denominators for the design-doc completion track:

| Denominator | Meaning | Completion requirement |
|---|---|---|
| `checklist_rows_1_20` | first twenty implementation rows | ExtractIR, runtime denotation, diagnostics, source spans, corpus fixtures, tests, and docs complete |
| `checklist_rows_41_56` | remaining checklist rows | all rows implemented with tests and docs |
| `rust_workspace_crates` | generated/runtime/ABI/validator/header crates | all crates present in Cargo workspace |
| `final_docs` | final documentation set | testing, coverage, diagnostics, crate design, release checklist, FFI docs |
| `property_seed_families` | deterministic property corpus families | every family represented in CI tests |
| `release_acceptance_gates` | required release gates | every gate scripted and documented |

A dashboard entry may be marked complete only when the implementation, tests,
and documentation are all present.

## Rows 41-63 completion

The remaining completion patch adds the `checklist_rows_41_63`,
`generated_subset_semantics_heads`, and `preservation_obligations` denominators.
Each denominator is complete only when the implementation module, Rust/Lean test,
and documentation page are all present. The gate is
`scripts/check-remaining-completion.py`.
