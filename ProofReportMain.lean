import LeanRustCore.ProofReport

/-- Generate a JSON proof report. Usage: `lake exe gen_proof_report [path]`. -/
def main : IO Unit := do
  let args ← IO.getArgs
  let out := match args.toList with
    | path :: _ => path
    | [] => "rust/proof-report.json"
  IO.FS.writeFile out LeanRustCore.ProofReport.reportJson
  IO.println s!"wrote proof report to {out}"
