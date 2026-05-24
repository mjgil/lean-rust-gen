import LeanRustCore.Examples

/-- Generate the extractor-owned ExtractIR snapshot. Usage: `lake exe gen_extract_ir [path]`. -/
def main (args : List String) : IO Unit := do
  let out := match args with
    | path :: _ => path
    | [] => "rust/extract-ir.txt"
  IO.FS.writeFile out LeanRustCore.Examples.extractedIRSnapshot
  IO.println s!"wrote ExtractIR snapshot to {out}"
