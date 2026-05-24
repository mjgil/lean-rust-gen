import LeanRustCore.Toolchain

/-- Generate build metadata. Usage: `lake exe gen_build_metadata [path]`. -/
def main (args : List String) : IO Unit := do
  let out := match args with
    | path :: _ => path
    | [] => "rust/build-metadata.json"
  IO.FS.writeFile out LeanRustCore.Toolchain.buildMetadataJson
  IO.println s!"wrote build metadata to {out}"
