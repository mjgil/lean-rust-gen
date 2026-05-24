import LeanRustCore.BoundaryExport

/-- Generate optional feature-gated raw ABI wrappers. Usage: `lake exe gen_boundary_exports [path]`. -/
def main (args : List String) : IO Unit := do
  let out := match args with
    | path :: _ => path
    | [] => "rust/src/ffi_generated.rs"
  IO.FS.writeFile out LeanRustCore.BoundaryExport.generatedBoundaryRust
  IO.println s!"wrote optional raw ABI wrappers to {out}"
