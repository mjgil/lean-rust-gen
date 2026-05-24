import LeanRustCore.ProofReport

/-- Generate a JSON proof report. Usage: `lake exe gen_proof_report [path]`. -/
def main (args : List String) : IO Unit := do
  let out := match args with
    | path :: _ => path
    | [] => "rust/proof-report.json"
  IO.FS.writeFile out LeanRustCore.ProofReport.reportJson
  IO.println s!"wrote proof report to {out}"
