import LeanRustCore.Examples

namespace LeanRustCore.TargetValidation

open LeanRustCore
open LeanRustCore.Examples

/-!
Phase-3 target translation-validation snapshot.

The direct emitter still owns Rust source generation.  This module emits a small,
deterministic Lean-side target snapshot that records the checked surface module as
Rust-facing declarations and normalized expression fingerprints.  The Rust
`semantic_validation` integration test parses `generated.rs` with `syn`,
reconstructs the same generated-subset target IR, and compares the two views.
-/

def targetValidationFormat : String := "lean-rust-core.target-validation.v1"

private def escapeChar : Char → String
  | '\\' => "\\\\"
  | '\n' => "\\n"
  | '\r' => "\\r"
  | '\t' => "\\t"
  | ',' => "\\,"
  | '|' => "\\|"
  | '(' => "\\("
  | ')' => "\\)"
  | '=' => "\\="
  | c => String.singleton c

private def escape (s : String) : String :=
  joinWith "" (s.toList.map escapeChar)

private def fingerprintType (ty : RType) : String :=
  rustType ty

private def fingerprintArg (arg : RArg) : String :=
  rustValueIdent "arg" arg.1 ++ ":" ++ fingerprintType arg.2

private def fingerprintEnumPath (ty : RType) (variant : String) : String :=
  match ty with
  | .enum name _ => rustTypeIdent name ++ "::" ++ rustVariantIdent variant
  | _ => rustVariantIdent variant

private def fingerprintBinders (binders : List String) : String :=
  joinWith "," (binders.map (rustValueIdent "value"))

partial def fingerprintSurfaceExpr : SurfaceExpr → String
  | .var name => "var(" ++ rustValueIdent "value" name ++ ")"
  | .litUnit => "unit"
  | .litBool true => "bool(true)"
  | .litBool false => "bool(false)"
  | .litU32 n => "lit(" ++ Nat.toString n ++ ")"
  | .litU64 n => "lit(" ++ Nat.toString n ++ ")"
  | .litI32 n => "lit(" ++ toString n ++ ")"
  | .litI64 n => "lit(" ++ toString n ++ ")"
  | .litChar c => "char(" ++ Nat.toString c.toNat ++ ")"
  | .litString s => "string(" ++ escape s ++ ")"
  | .letIn name value body =>
      "let(" ++ rustValueIdent "tmp" name ++ "," ++ fingerprintSurfaceExpr value ++ "," ++ fingerprintSurfaceExpr body ++ ")"
  | .ite c a b =>
      "if(" ++ fingerprintSurfaceExpr c ++ "," ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .matchBool c whenTrue whenFalse =>
      "match_bool(" ++ fingerprintSurfaceExpr c ++ "," ++ fingerprintSurfaceExpr whenTrue ++ "," ++ fingerprintSurfaceExpr whenFalse ++ ")"
  | .matchOption target noneCase someName someCase =>
      "match_option(" ++ fingerprintSurfaceExpr target ++ ",none=>" ++ fingerprintSurfaceExpr noneCase ++
      "|some(" ++ rustValueIdent "value" someName ++ ")=>" ++ fingerprintSurfaceExpr someCase ++ ")"
  | .matchEnum enumTy target branches =>
      let renderedBranches := branches.map (fun branch =>
        fingerprintEnumPath enumTy branch.1 ++ "(" ++ fingerprintBinders branch.2.1 ++ ")=>" ++ fingerprintSurfaceExpr branch.2.2)
      "match_enum(" ++ fingerprintSurfaceExpr target ++ "," ++ joinWith "|" renderedBranches ++ ")"
  | .not a => "not(" ++ fingerprintSurfaceExpr a ++ ")"
  | .and a b => "and(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .or a b => "or(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .eq _ a b => "eq(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .lt _ a b => "lt(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .le _ a b => "le(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .gt _ a b => "gt(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .ge _ a b => "ge(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .add _ a b => "add(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .sub _ a b => "sub(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .mul _ a b => "mul(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .min _ a b => "min(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .max _ a b => "max(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .optionNone _ => "none"
  | .optionSome a => "some(" ++ fingerprintSurfaceExpr a ++ ")"
  | .resultOk _ a => "ok(" ++ fingerprintSurfaceExpr a ++ ")"
  | .resultErr _ e => "err(" ++ fingerprintSurfaceExpr e ++ ")"
  | .structLit ty fields =>
      let typeName := match ty with | .struct name _ => rustTypeIdent name | _ => "<malformed-struct>"
      let renderedFields := fields.map (fun field => rustFieldIdent field.1 ++ "=" ++ fingerprintSurfaceExpr field.2)
      "struct(" ++ typeName ++ "," ++ joinWith "," renderedFields ++ ")"
  | .field target fieldName =>
      "field(" ++ fingerprintSurfaceExpr target ++ "," ++ rustFieldIdent fieldName ++ ")"
  | .enumVariant ty variant payload =>
      let renderedPayload := joinWith "," (payload.map fingerprintSurfaceExpr)
      if renderedPayload == "" then
        "enum(" ++ fingerprintEnumPath ty variant ++ ")"
      else
        "enum(" ++ fingerprintEnumPath ty variant ++ "," ++ renderedPayload ++ ")"
  | .call name _ _ args =>
      "call(" ++ rustValueIdent "generated" name ++ "," ++ joinWith "," (args.map fingerprintSurfaceExpr) ++ ")"
  | .callValue fn _ _ arg =>
      "call_value(" ++ fingerprintSurfaceExpr fn ++ "," ++ fingerprintSurfaceExpr arg ++ ")"
  | .listMap binder _ _ target body =>
      "list_map(" ++ rustValueIdent "value" binder ++ "," ++
      fingerprintSurfaceExpr target ++ "," ++ fingerprintSurfaceExpr body ++ ")"
  | .listFoldl accName elemName _ _ init target body =>
      "list_foldl(" ++ rustValueIdent "acc" accName ++ "," ++
      rustValueIdent "item" elemName ++ "," ++
      fingerprintSurfaceExpr init ++ "," ++ fingerprintSurfaceExpr target ++ "," ++ fingerprintSurfaceExpr body ++ ")"
  | .natFold idxName accName _ init n body =>
      "nat_fold(" ++ rustValueIdent "idx" idxName ++ "," ++ rustValueIdent "acc" accName ++ "," ++
      fingerprintSurfaceExpr init ++ "," ++ fingerprintSurfaceExpr n ++ "," ++ fingerprintSurfaceExpr body ++ ")"

private def structLine (s : SurfaceStruct) : String :=
  "TYPE\tstruct\t" ++ rustTypeIdent s.name ++ "\t" ++
  joinWith "," (s.fields.map (fun field => rustFieldIdent field.1 ++ ":" ++ fingerprintType field.2))

private def enumVariantLine (variant : String × List RType) : String :=
  if variant.2.isEmpty then
    rustVariantIdent variant.1
  else
    rustVariantIdent variant.1 ++ "(" ++ joinWith "," (variant.2.map fingerprintType) ++ ")"

private def enumLine (e : SurfaceEnum) : String :=
  "TYPE\tenum\t" ++ rustTypeIdent e.name ++ "\t" ++ joinWith "|" (e.variants.map enumVariantLine)

private def funLine (f : SurfaceFun) : String :=
  "FN\t" ++ rustValueIdent "generated" f.name ++ "\t" ++
  joinWith "," (f.args.map fingerprintArg) ++ "\t" ++
  fingerprintType f.ret ++ "\t" ++
  fingerprintSurfaceExpr f.body

/-- The checked surface module used for target validation. -/
def targetValidationModule : SurfaceModule :=
  SurfaceModule.fromFunctions LeanRustCore.Examples.extractedSurfaceFunctions

/-- Text snapshot consumed by `rust/tests/semantic_validation.rs`. -/
def targetValidationSnapshot : String :=
  let typeLines := targetValidationModule.structs.map structLine ++ targetValidationModule.enums.map enumLine
  let funLines := targetValidationModule.functions.map funLine
  joinWith "\n" (
    [ "FORMAT\t" ++ targetValidationFormat,
      "ARCH\tdirect-lean-emits-rust",
      "TYPE_COUNT\t" ++ Nat.toString typeLines.length,
      "FN_COUNT\t" ++ Nat.toString funLines.length ] ++
    typeLines ++ funLines) ++ "\n"

end LeanRustCore.TargetValidation
