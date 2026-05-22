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

def targetValidationFormat : String := "lean-rust-core.target-validation.v2"

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

private partial def fingerprintPattern (ty : RType) : SurfacePattern → String
  | .wildcard => "_"
  | .var name => "varpat(" ++ rustValueIdent "value" name ++ ")"
  | .unit => "unit"
  | .bool true => "true"
  | .bool false => "false"
  | .optionNone => "None"
  | .optionSome inner =>
      match ty with
      | .option innerTy => "Some(" ++ fingerprintPattern innerTy inner ++ ")"
      | _ => "Some(_)"
  | .enumCtor variant payload =>
      match ty with
      | .enum _ variants =>
          let payloadTypes := match lookupVariantPayloadLocal variants variant with | some tys => tys | none => []
          let rendered := (payload.zip payloadTypes).map (fun pair => fingerprintPattern pair.2 pair.1)
          fingerprintEnumPath ty variant ++ "(" ++ joinWith "," rendered ++ ")"
      | _ => rustVariantIdent variant
  | .prod a b =>
      match ty with
      | .prod aTy bTy => "(" ++ fingerprintPattern aTy a ++ "," ++ fingerprintPattern bTy b ++ ")"
      | _ => "(_,_)"
where
  lookupVariantPayloadLocal (variants : List (String × List RType)) (name : String) : Option (List RType) :=
    match variants with
    | [] => none
    | (candidate, payload) :: rest => if candidate == name then some payload else lookupVariantPayloadLocal rest name

private def fingerprintDefaultValue : RType → String
  | .unit => "default(())"
  | .bool => "default(bool)"
  | .ordering => "default(Ordering)"
  | .nat => "default(num_bigint::BigUint)"
  | .int => "default(num_bigint::BigInt)"
  | .u32 => "default(u32)"
  | .u64 => "default(u64)"
  | .i32 => "default(i32)"
  | .i64 => "default(i64)"
  | .char => "default(char)"
  | .string => "default(String)"
  | .option _ => "none"
  | .list _ | .array _ | .vector _ _ => "vec()"
  | .boxed inner => "box(" ++ fingerprintDefaultValue inner ++ ")"
  | .recursive name => "recursive(" ++ rustTypeIdent name ++ ")"
  | .fin _ => "default(u32)"
  | .subtype t => fingerprintDefaultValue t
  | .prod a b => "tuple(" ++ fingerprintDefaultValue a ++ "," ++ fingerprintDefaultValue b ++ ")"
  | .sum a _ => "err(" ++ fingerprintDefaultValue a ++ ")"
  | .result _ err => "err(" ++ fingerprintDefaultValue err ++ ")"
  | .struct name fields =>
      let rendered := fields.map (fun field => rustFieldIdent field.1 ++ "=" ++ fingerprintDefaultValue field.2)
      "struct(" ++ rustTypeIdent name ++ "," ++ joinWith "," rendered ++ ")"
  | .enum name variants =>
      match variants with
      | [] => "enum(" ++ rustTypeIdent name ++ "::<empty>)"
      | (variant, payload) :: _ =>
          let renderedPayload := joinWith "," (payload.map fingerprintDefaultValue)
          if renderedPayload == "" then
            "enum(" ++ rustTypeIdent name ++ "::" ++ rustVariantIdent variant ++ ")"
          else
            "enum(" ++ rustTypeIdent name ++ "::" ++ rustVariantIdent variant ++ "," ++ renderedPayload ++ ")"
  | .func _ _ => "default_fn"

partial def fingerprintSurfaceExpr : SurfaceExpr → String
  | .var name => "var(" ++ rustValueIdent "value" name ++ ")"
  | .litUnit => "unit"
  | .litBool true => "bool(true)"
  | .litBool false => "bool(false)"
  | .litNat n => "lit(" ++ Nat.toString n ++ ")"
  | .litInt n => "lit(" ++ toString n ++ ")"
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
  | .matchPattern scrutTy target arms =>
      let renderedArms := arms.map (fun arm =>
        fingerprintPattern scrutTy arm.1 ++ "=>" ++ fingerprintSurfaceExpr arm.2)
      "match_pattern(" ++ fingerprintSurfaceExpr target ++ "," ++ joinWith "|" renderedArms ++ ")"
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
  | .compare _ a b => "compare(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
  | .optionNone _ => "none"
  | .optionSome a => "some(" ++ fingerprintSurfaceExpr a ++ ")"
  | .resultOk _ a => "ok(" ++ fingerprintSurfaceExpr a ++ ")"
  | .resultErr _ e => "err(" ++ fingerprintSurfaceExpr e ++ ")"
  | .prodLit a b => "tuple(" ++ fingerprintSurfaceExpr a ++ "," ++ fingerprintSurfaceExpr b ++ ")"
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
  | .boxNew _ value => "box(" ++ fingerprintSurfaceExpr value ++ ")"
  | .boxDeref _ value => "deref(" ++ fingerprintSurfaceExpr value ++ ")"
  | .closureApply binder _ _ arg body =>
      "closure_apply(" ++ rustValueIdent "value" binder ++ "," ++ fingerprintSurfaceExpr arg ++ "," ++ fingerprintSurfaceExpr body ++ ")"
  | .defaultValue ty => fingerprintDefaultValue ty
  | .toStringValue ty value => "to_string(" ++ fingerprintType ty ++ "," ++ fingerprintSurfaceExpr value ++ ")"
  | .reprValue ty value => "repr(" ++ fingerprintType ty ++ "," ++ fingerprintSurfaceExpr value ++ ")"
  | .listMap binder _ _ target body =>
      "list_map(" ++ rustValueIdent "value" binder ++ "," ++
      fingerprintSurfaceExpr target ++ "," ++ fingerprintSurfaceExpr body ++ ")"
  | .listFilter binder _ target predicate =>
      "list_filter(" ++ rustValueIdent "value" binder ++ "," ++
      fingerprintSurfaceExpr target ++ "," ++ fingerprintSurfaceExpr predicate ++ ")"
  | .listFoldl accName elemName _ _ init target body =>
      "list_foldl(" ++ rustValueIdent "acc" accName ++ "," ++
      rustValueIdent "item" elemName ++ "," ++
      fingerprintSurfaceExpr init ++ "," ++ fingerprintSurfaceExpr target ++ "," ++ fingerprintSurfaceExpr body ++ ")"
  | .listFoldr elemName accName _ _ target init body =>
      "list_foldr(" ++ rustValueIdent "item" elemName ++ "," ++ rustValueIdent "acc" accName ++ "," ++
      fingerprintSurfaceExpr target ++ "," ++ fingerprintSurfaceExpr init ++ "," ++ fingerprintSurfaceExpr body ++ ")"
  | .listAny binder _ target predicate =>
      "list_any(" ++ rustValueIdent "value" binder ++ "," ++ fingerprintSurfaceExpr target ++ "," ++ fingerprintSurfaceExpr predicate ++ ")"
  | .listAll binder _ target predicate =>
      "list_all(" ++ rustValueIdent "value" binder ++ "," ++ fingerprintSurfaceExpr target ++ "," ++ fingerprintSurfaceExpr predicate ++ ")"
  | .arrayMap binder _ _ target body =>
      "list_map(" ++ rustValueIdent "value" binder ++ "," ++ fingerprintSurfaceExpr target ++ "," ++ fingerprintSurfaceExpr body ++ ")"
  | .arrayFoldl accName elemName _ _ init target body =>
      "list_foldl(" ++ rustValueIdent "acc" accName ++ "," ++ rustValueIdent "item" elemName ++ "," ++
      fingerprintSurfaceExpr init ++ "," ++ fingerprintSurfaceExpr target ++ "," ++ fingerprintSurfaceExpr body ++ ")"
  | .optionMap binder _ _ target body =>
      "match_option(" ++ fingerprintSurfaceExpr target ++ ",none=>none|some(" ++ rustValueIdent "value" binder ++ ")=>some(" ++ fingerprintSurfaceExpr body ++ "))"
  | .optionBind binder _ _ target body =>
      "match_option(" ++ fingerprintSurfaceExpr target ++ ",none=>none|some(" ++ rustValueIdent "value" binder ++ ")=>" ++ fingerprintSurfaceExpr body ++ ")"
  | .resultMapOk binder _ _ _ target body =>
      "match_enum(" ++ fingerprintSurfaceExpr target ++ ",Err(__lrc_err)=>err(var(__lrc_err))|Ok(" ++ rustValueIdent "value" binder ++ ")=>ok(" ++ fingerprintSurfaceExpr body ++ "))"
  | .resultBind binder _ _ _ target body =>
      "match_enum(" ++ fingerprintSurfaceExpr target ++ ",Err(__lrc_err)=>err(var(__lrc_err))|Ok(" ++ rustValueIdent "value" binder ++ ")=>" ++ fingerprintSurfaceExpr body ++ ")"
  | .subtypeErase _ value => fingerprintSurfaceExpr value
  | .subtypeVal _ value => fingerprintSurfaceExpr value
  | .finCheck bound value =>
      "if(lt(" ++ fingerprintSurfaceExpr value ++ ",lit(" ++ Nat.toString bound ++ ")),some(" ++ fingerprintSurfaceExpr value ++ "),none)"
  | .finMk _ value => fingerprintSurfaceExpr value
  | .finVal _ value => fingerprintSurfaceExpr value
  | .vectorCheck elemTy bound value =>
      "vector_check(" ++ rustType elemTy ++ "," ++ Nat.toString bound ++ "," ++ fingerprintSurfaceExpr value ++ ")"
  | .vectorErase _ _ value => fingerprintSurfaceExpr value
  | .vectorMap binder _ _ _ target body =>
      "list_map(" ++ rustValueIdent "value" binder ++ "," ++ fingerprintSurfaceExpr target ++ "," ++ fingerprintSurfaceExpr body ++ ")"
  | .listLength _ target =>
      "list_length(" ++ fingerprintSurfaceExpr target ++ ")"
  | .natFold idxName accName _ init n body =>
      "nat_fold(" ++ rustValueIdent "idx" idxName ++ "," ++ rustValueIdent "acc" accName ++ "," ++
      fingerprintSurfaceExpr init ++ "," ++ fingerprintSurfaceExpr n ++ "," ++ fingerprintSurfaceExpr body ++ ")"
  | .tailRecNat counterName accName _ counter init body =>
      "tail_rec_nat(" ++ rustValueIdent "counter" counterName ++ "," ++ rustValueIdent "acc" accName ++ "," ++
      fingerprintSurfaceExpr counter ++ "," ++ fingerprintSurfaceExpr init ++ "," ++ fingerprintSurfaceExpr body ++ ")"

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
