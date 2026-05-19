import LeanRustCore.IR
import LeanRustCore.Surface
import LeanRustCore.ChimeraBoundary

namespace LeanRustCore.Lowering

open LeanRustCore

/-- Source items accepted by the direct Lean→Rust compiler. -/
inductive SourceItem where
  | proofCarrying : RFun → SourceItem
  | extracted : SurfaceFun → SourceItem


/-- Current supported runtime types for direct safe Rust emission. -/
def supportedRustType : RType → Bool
  | .unit | .bool | .u32 | .u64 => true
  | .option t => supportedRustType t
  | .result ok err => supportedRustType ok && supportedRustType err

/-- Check all function argument and return types are in the supported subset. -/
def checkFunctionShape (name : String) (args : List RArg) (ret : RType) : CompatibilityReport :=
  let argTypesOk := args.all (fun arg => supportedRustType arg.2)
  let retOk := supportedRustType ret
  if argTypesOk && retOk then
    { code := .supported, detail := "function `" ++ name ++ "` shape is supported" }
  else
    { code := .unsupportedType, detail := "function `" ++ name ++ "` uses a type outside the first Rust emitter subset" }

/-- Lower/check a first-pass source item. -/
def lowerItem : SourceItem → Except CompatibilityReport SourceItem
  | .proofCarrying f =>
      let report := checkFunctionShape f.name f.args f.ret
      if report.code == .supported then Except.ok (.proofCarrying f) else Except.error report
  | .extracted f => do
      let report := checkFunctionShape f.name f.args f.ret
      if report.code == .supported then
        let checked ← checkSurfaceFun f
        pure (.extracted checked)
      else
        throw report

/-- Stability theorem: primitive-only function shapes are accepted. -/
theorem primitive_shape_supported :
  (checkFunctionShape "id" [("x", .u32)] .u32).code = .supported := by
  rfl

end LeanRustCore.Lowering
