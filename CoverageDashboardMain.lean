import LeanRustCore.ValidationV2

/-- Generate the coverage dashboard. Usage: `lake exe gen_coverage_dashboard [path]`. -/
def main : IO Unit := do
  let args ← IO.getArgs
  let out := match args.toList with
    | path :: _ => path
    | [] => "rust/coverage-dashboard.json"
  IO.FS.writeFile out LeanRustCore.ValidationV2.coverageDashboardJson
  IO.println s!"wrote coverage dashboard to {out}"
