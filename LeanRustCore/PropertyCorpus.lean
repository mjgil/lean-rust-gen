import Lean

namespace LeanRustCore.PropertyCorpus

/-!
Task 41 property/fuzz corpus metadata.

The deterministic lane is required for CI.  Optional fuzzing can expand the same
families locally or in nightly jobs, but a feature cannot be marked complete
unless it has deterministic property seeds, a Rust or Lean test owner, and user
facing documentation.
-/

structure PropertySeedFamily where
  name : String
  lane : String
  seedCount : Nat
  owner : String
  documentation : String
  deriving Repr, BEq

private def joinWithLocal (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWithLocal sep xs

/-- Deterministic seed families required by the final checklist rows. -/
def seedFamilies : List PropertySeedFamily := [
  { name := "numeric-edge-cases", lane := "deterministic", seedCount := 12, owner := "crates/runtime", documentation := "docs/TESTING.md#numeric-edge-cases" },
  { name := "container-roundtrip", lane := "deterministic", seedCount := 10, owner := "crates/runtime", documentation := "docs/TESTING.md#container-roundtrip" },
  { name := "closure-and-dictionary", lane := "deterministic", seedCount := 8, owner := "rust/tests/property_validation.rs", documentation := "docs/TESTING.md#closure-and-dictionary" },
  { name := "ffi-handle-lifecycle", lane := "deterministic+ffi", seedCount := 9, owner := "crates/abi", documentation := "docs/TESTING.md#ffi-handle-lifecycle" },
  { name := "generated-subset-target-grammar", lane := "deterministic", seedCount := 14, owner := "crates/validate", documentation := "docs/SEMANTIC_VALIDATION.md" }
]

/-- Total deterministic property seeds recorded by the corpus metadata. -/
def deterministicSeedCount : Nat :=
  seedFamilies.foldl (fun total family => total + family.seedCount) 0

/-- Human-readable summary for validation/proof reports. -/
def propertyCorpusSummary : String :=
  "property/fuzz corpus requires deterministic CI seeds before completion; families: " ++
  joinWithLocal ", " (seedFamilies.map (fun family => family.name ++ "=" ++ toString family.seedCount))

end LeanRustCore.PropertyCorpus
