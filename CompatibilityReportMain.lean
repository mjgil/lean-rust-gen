import LeanRustCore.Examples

/-- Generate a JSON compatibility report. Usage: `lake exe gen_compatibility_report [path]`. -/
def main (args : List String) : IO Unit := do
  let out := match args with
    | path :: _ => path
    | [] => "rust/compatibility-report.json"
  IO.FS.writeFile out LeanRustCore.Examples.generatedCompatibilityReport
  IO.println s!"wrote compatibility report to {out}"
