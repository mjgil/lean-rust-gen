import LeanRustCore.ValidationV2

/-- Generate the coverage dashboard. Usage: `lake exe gen_coverage_dashboard [path]`. -/
def main (args : List String) : IO Unit := do
  let out := match args with
    | path :: _ => path
    | [] => "rust/coverage-dashboard.json"
  IO.FS.writeFile out LeanRustCore.ValidationV2.coverageDashboardJson
  IO.println s!"wrote coverage dashboard to {out}"
