import LeanRustCore.Examples

/-- Generate Rust source. Usage: `lake exe gen_rust [path]`. -/
def main (args : List String) : IO Unit := do
  let out := match args with
    | path :: _ => path
    | [] => "rust/src/generated.rs"
  IO.FS.writeFile out LeanRustCore.Examples.generatedRust
  IO.println s!"wrote extracted Lean→Rust output to {out}"
