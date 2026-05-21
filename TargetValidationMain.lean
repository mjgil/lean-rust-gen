import LeanRustCore.TargetValidation

/-- Generate the Lean-side target-validation snapshot. Usage: `lake exe gen_target_validation [path]`. -/
def main : IO Unit := do
  let args ← IO.getArgs
  let out := match args.toList with
    | path :: _ => path
    | [] => "rust/target-validation.txt"
  IO.FS.writeFile out LeanRustCore.TargetValidation.targetValidationSnapshot
  IO.println s!"wrote target-validation snapshot to {out}"
