# Optional fuzz corpus

The CI contract is deterministic: every feature must have stable property seeds
in `corpus/property/seeds.json`. Optional fuzzing may expand those families in
nightly jobs, but a feature cannot rely on fuzz-only coverage to be marked
complete.
