import LeanRustCore.Differential

/-- Generate Rust differential tests. Usage: `lake exe gen_differential_tests [path]`. -/
def main (args : List String) : IO Unit := do
  let out := match args with
    | path :: _ => path
    | [] => "rust/tests/differential_generated.rs"
  IO.FS.writeFile out LeanRustCore.Differential.generatedDifferentialRustTests
  IO.println s!"wrote Lean-evaluator differential Rust tests to {out}"
