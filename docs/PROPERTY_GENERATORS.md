# Property generators

Deterministic property generators are mandatory in CI. Optional fuzzing may
expand these generators in nightly jobs, but fuzz-only coverage is not accepted
as a completion criterion.

Families:

| Family | Minimization policy |
|---|---|
| base scalars | smallest numeric counterexample |
| containers | shortest collection, then smallest elements |
| recursive data | minimum tree/expression depth |
| closures and dictionaries | smallest closure/dictionary tag |
| target grammar | smallest target term depth |
| FFI handles | shortest handle lifecycle trace |

Every generator family must have stable seeds, tests, documentation, and a
minimization policy.
