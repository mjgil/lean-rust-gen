import LeanRustCore.RustValidation

/-- Generate a JSON Rust-validation report. Usage: `lake exe gen_validation_report [path]`. -/
def main (args : List String) : IO Unit := do
  let out := match args with
    | path :: _ => path
    | [] => "rust/validation-report.json"
  IO.FS.writeFile out LeanRustCore.RustValidation.validationReportJson
  IO.println s!"wrote Rust validation report to {out}"
