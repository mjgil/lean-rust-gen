import LeanRustCore.Surface
import LeanRustCore.EmitRust
import LeanRustCore.StdLowering
import LeanRustCore.TypeclassPolicy
import LeanRustCore.DependentErasure
import LeanRustCore.RecursiveData
import LeanRustCore.Diagnostics

namespace LeanRustCore.ExtractIR

open LeanRustCore

/-!
A real, explicit extraction-IR metadata layer.

`SurfaceExpr` remains the checked executable IR used by the emitter and the
Lean-side differential evaluator. `ExtractIR` sits immediately before it: it
records source origin, source-span metadata when Lean can provide it, erased
binders, recognized recursor and Std-lowering families, resolved dictionary
arguments, feature tags, and structured rejection reasons.  The lowering step is
intentionally conservative: only `ExtractExpr.surface` is executable today;
policy-only nodes must either be discharged to a `SurfaceExpr` or reported as an
unsupported diagnostic before Rust emission.
-/

/-- Coarse feature families used by reports and corpus diagnostics. -/
inductive FeatureTag where
  | primitive
  | exactInteger
  | fixedWidthInteger
  | container
  | structEnum
  | genericMonomorphization
  | automaticMonomorphization
  | helperExtraction
  | proofErasure
  | patternMatch
  | structuralLoop
  | tailLoop
  | stdLowering
  | typeclassSpecialization
  | pureEffect
  | dependentErasure
  | closureConversion
  | defunctionalization
  | recursiveData
  | ffiBoundaryEligible
  | unsupported
  deriving Repr, BEq, DecidableEq

/-- Stable string spelling for feature tags in JSON reports. -/
def featureTagName : FeatureTag → String
  | .primitive => "primitive"
  | .exactInteger => "exact-integer-mode"
  | .fixedWidthInteger => "fixed-width-integer"
  | .container => "container-shape"
  | .structEnum => "struct-enum-shape"
  | .genericMonomorphization => "generic-monomorphization"
  | .automaticMonomorphization => "automatic-monomorphization"
  | .helperExtraction => "helper-extraction"
  | .proofErasure => "proof-erasure"
  | .patternMatch => "general-pattern-match"
  | .structuralLoop => "structural-loop"
  | .tailLoop => "tail-recursion-loop"
  | .stdLowering => "std-lowering"
  | .typeclassSpecialization => "typeclass-specialization"
  | .pureEffect => "pure-effect-lowering"
  | .dependentErasure => "dependent-erasure"
  | .closureConversion => "closure-conversion"
  | .defunctionalization => "defunctionalization"
  | .recursiveData => "recursive-data"
  | .ffiBoundaryEligible => "ffi-boundary-eligible"
  | .unsupported => "unsupported"

private def containsTag (needle : FeatureTag) : List FeatureTag → Bool
  | [] => false
  | tag :: rest => tag == needle || containsTag needle rest

private def addTag (tag : FeatureTag) (tags : List FeatureTag) : List FeatureTag :=
  if containsTag tag tags then tags else tags ++ [tag]

private def unionTags (a b : List FeatureTag) : List FeatureTag :=
  b.foldl (fun acc tag => addTag tag acc) a

private def unions (groups : List (List FeatureTag)) : List FeatureTag :=
  groups.foldl unionTags []

private partial def typeFeatures : RType → List FeatureTag
  | .unit | .bool | .ordering | .u32 | .u64 | .i32 | .i64 | .char | .string => [.primitive]
  | .nat | .int => [.exactInteger]
  | .option t | .list t | .array t | .boxed t | .subtype t => addTag .container (typeFeatures t)
  | .prod a b | .sum a b | .func a b | .result a b => addTag .container (unionTags (typeFeatures a) (typeFeatures b))
  | .fin _ => [.dependentErasure, .primitive]
  | .vector t _ => addTag .dependentErasure (addTag .container (typeFeatures t))
  | .recursive _ => [.recursiveData]
  | .struct _ fields => addTag .structEnum (unions (fields.map (fun field => typeFeatures field.2)))
  | .enum _ variants => addTag .structEnum (unions (variants.map (fun variant => unions (variant.2.map typeFeatures))))

/-- Extract feature tags from an already checked surface expression tree. -/
partial def exprFeatures : SurfaceExpr → List FeatureTag
  | .var _ | .litUnit | .litBool _ | .litNat _ | .litInt _ | .litU32 _ | .litU64 _ | .litI32 _ | .litI64 _ | .litChar _ | .litString _ => [.primitive]
  | .letIn _ value body => unionTags (exprFeatures value) (exprFeatures body)
  | .ite c a b | .matchBool c a b => addTag .patternMatch (unionTags (exprFeatures c) (unionTags (exprFeatures a) (exprFeatures b)))
  | .matchOption target noneCase _ someCase => addTag .patternMatch (unionTags (exprFeatures target) (unionTags (exprFeatures noneCase) (exprFeatures someCase)))
  | .matchEnum _ target branches => addTag .patternMatch (unionTags (exprFeatures target) (unions (branches.map (fun b => exprFeatures b.2.2))))
  | .matchPattern _ target arms => addTag .patternMatch (unionTags (exprFeatures target) (unions (arms.map (fun arm => exprFeatures arm.2))))
  | .not a => exprFeatures a
  | .and a b | .or a b | .eq _ a b | .lt _ a b | .le _ a b | .gt _ a b | .ge _ a b | .add _ a b | .sub _ a b | .mul _ a b | .min _ a b | .max _ a b | .compare _ a b => unionTags (exprFeatures a) (exprFeatures b)
  | .optionNone ty | .defaultValue ty => typeFeatures ty
  | .optionSome a | .resultOk _ a | .resultErr _ a => exprFeatures a
  | .prodLit a b => addTag .container (unionTags (exprFeatures a) (exprFeatures b))
  | .structLit ty fields => addTag .structEnum (unionTags (typeFeatures ty) (unions (fields.map (fun f => exprFeatures f.2))))
  | .field target _ => addTag .structEnum (exprFeatures target)
  | .enumVariant ty _ payload => addTag .structEnum (unionTags (typeFeatures ty) (unions (payload.map exprFeatures)))
  | .call _ _ _ args => unions (args.map exprFeatures)
  | .callValue fn _ _ arg => addTag .closureConversion (unionTags (exprFeatures fn) (exprFeatures arg))
  | .boxNew ty value | .boxDeref ty value => addTag .recursiveData (unionTags (typeFeatures ty) (exprFeatures value))
  | .closureApply _ argTy retTy arg body => addTag .closureConversion (unionTags (typeFeatures argTy) (unionTags (typeFeatures retTy) (unionTags (exprFeatures arg) (exprFeatures body))))
  | .toStringValue ty value | .reprValue ty value => addTag .typeclassSpecialization (unionTags (typeFeatures ty) (exprFeatures value))
  | .listMap _ src dst target body | .arrayMap _ src dst target body => addTag .stdLowering (addTag .structuralLoop (unionTags (typeFeatures src) (unionTags (typeFeatures dst) (unionTags (exprFeatures target) (exprFeatures body)))))
  | .listFilter _ elem target predicate | .listAny _ elem target predicate | .listAll _ elem target predicate => addTag .stdLowering (addTag .structuralLoop (unionTags (typeFeatures elem) (unionTags (exprFeatures target) (exprFeatures predicate))))
  | .listAppend elem left right => addTag .stdLowering (addTag .structuralLoop (unionTags (typeFeatures elem) (unionTags (exprFeatures left) (exprFeatures right))))
  | .listFind _ elem target predicate => addTag .stdLowering (addTag .structuralLoop (unionTags (typeFeatures elem) (unionTags (exprFeatures target) (exprFeatures predicate))))
  | .listFoldl _ _ acc elem init target body | .arrayFoldl _ _ acc elem init target body => addTag .stdLowering (addTag .structuralLoop (unionTags (typeFeatures acc) (unionTags (typeFeatures elem) (unionTags (exprFeatures init) (unionTags (exprFeatures target) (exprFeatures body))))))
  | .listFoldr _ _ elem acc target init body => addTag .stdLowering (addTag .structuralLoop (unionTags (typeFeatures elem) (unionTags (typeFeatures acc) (unionTags (exprFeatures target) (unionTags (exprFeatures init) (exprFeatures body))))))
  | .arrayPush elem target value => addTag .stdLowering (addTag .structuralLoop (unionTags (typeFeatures elem) (unionTags (exprFeatures target) (exprFeatures value))))
  | .optionMap _ src dst target body | .optionBind _ src dst target body => addTag .pureEffect (addTag .stdLowering (unionTags (typeFeatures src) (unionTags (typeFeatures dst) (unionTags (exprFeatures target) (exprFeatures body)))))
  | .resultMapOk _ ok err dst target body | .resultBind _ ok err dst target body => addTag .pureEffect (addTag .stdLowering (unionTags (typeFeatures ok) (unionTags (typeFeatures err) (unionTags (typeFeatures dst) (unionTags (exprFeatures target) (exprFeatures body))))))
  | .resultMapErr _ ok err outErr target body => addTag .pureEffect (addTag .stdLowering (unionTags (typeFeatures ok) (unionTags (typeFeatures err) (unionTags (typeFeatures outErr) (unionTags (exprFeatures target) (exprFeatures body))))))
  | .subtypeErase ty value | .subtypeVal ty value => addTag .dependentErasure (unionTags (typeFeatures ty) (exprFeatures value))
  | .finCheck _ value | .finMk _ value | .finVal _ value => addTag .dependentErasure (exprFeatures value)
  | .vectorCheck elemTy _ value | .vectorErase elemTy _ value => addTag .dependentErasure (unionTags (typeFeatures elemTy) (exprFeatures value))
  | .vectorMap _ elemSrc elemDst _ target body => addTag .dependentErasure (addTag .stdLowering (unionTags (typeFeatures elemSrc) (unionTags (typeFeatures elemDst) (unionTags (exprFeatures target) (exprFeatures body)))))
  | .listLength elem target => addTag .structuralLoop (unionTags (typeFeatures elem) (exprFeatures target))
  | .natFold _ _ acc init n body => addTag .structuralLoop (unionTags (typeFeatures acc) (unionTags (exprFeatures init) (unionTags (exprFeatures n) (exprFeatures body))))
  | .tailRecNat _ _ acc counter init body => addTag .tailLoop (unionTags (typeFeatures acc) (unionTags (exprFeatures counter) (unionTags (exprFeatures init) (exprFeatures body))))

/-- Feature tags for a checked surface function. -/
def functionFeatureTags (f : SurfaceFun) : List FeatureTag :=
  unionTags (unions (f.args.map (fun arg => typeFeatures arg.2))) (unionTags (typeFeatures f.ret) (exprFeatures f.body))

/-- Stable string feature tags for a checked surface function. -/
def functionFeatures (f : SurfaceFun) : List String :=
  (functionFeatureTags f).map featureTagName

/-- Normalized pre-surface expression forms that can carry source metadata. -/
inductive ExtractExpr where
  | surface : SurfaceExpr → ExtractExpr
  | erasedBinder : String → RType → ExtractExpr → ExtractExpr
  | recognizedRecursor : String → List ExtractExpr → ExtractExpr
  | recognizedStdLowering : String → List ExtractExpr → ExtractExpr
  | dictionaryArgument : String → String → ExtractExpr
  | rejected : String → String → ExtractExpr
  deriving Repr, BEq

/-- Lower executable ExtractIR expressions to SurfaceExpr, rejecting policy-only residue. -/
partial def lowerExpr? : ExtractExpr → Except String SurfaceExpr
  | .surface expr => .ok expr
  | .erasedBinder _ _ body => lowerExpr? body
  | .recognizedRecursor family _ => .error ("recognized recursor `" ++ family ++ "` was not discharged to SurfaceExpr")
  | .recognizedStdLowering family _ => .error ("Std lowering `" ++ family ++ "` was not discharged to SurfaceExpr")
  | .dictionaryArgument cls inst => .error ("typeclass dictionary `" ++ cls ++ "`/`" ++ inst ++ "` was not specialized or generated")
  | .rejected code detail => .error (code ++ ": " ++ detail)

/-- ExtractIR declaration records used by the mandatory pre-surface lowering stage. -/
structure ExtractDecl where
  source : String
  rustName : String
  args : List RArg
  ret : RType
  body : ExtractExpr
  deriving Repr, BEq

/-- Lower a complete ExtractIR declaration into a SurfaceFun. -/
def lowerDecl? (decl : ExtractDecl) : Except String SurfaceFun := do
  let body ← lowerExpr? decl.body
  pure { name := decl.rustName, args := decl.args, ret := decl.ret, body := body }

def extractIRFormat : String := "lean-rust-core.extract-ir.v1"

private def snapshotEscapeChar : Char → String
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

private def snapshotEscape (s : String) : String :=
  joinWith "" (s.toList.map snapshotEscapeChar)

private def fingerprintType (ty : RType) : String :=
  rustType ty

private def fingerprintArg (arg : RArg) : String :=
  rustValueIdent "arg" arg.1 ++ ":" ++ fingerprintType arg.2

partial def fingerprintExtractExpr : ExtractExpr → String
  | .surface expr => "surface(" ++ snapshotEscape (reprStr expr) ++ ")"
  | .erasedBinder name ty body =>
      "erased_binder(" ++ rustValueIdent "proof" name ++ ":" ++ fingerprintType ty ++ "," ++ fingerprintExtractExpr body ++ ")"
  | .recognizedRecursor family args =>
      "recognized_recursor(" ++ snapshotEscape family ++ "," ++ joinWith "," (args.map fingerprintExtractExpr) ++ ")"
  | .recognizedStdLowering family args =>
      "recognized_std(" ++ snapshotEscape family ++ "," ++ joinWith "," (args.map fingerprintExtractExpr) ++ ")"
  | .dictionaryArgument cls inst =>
      "dictionary(" ++ snapshotEscape cls ++ "," ++ snapshotEscape inst ++ ")"
  | .rejected code detail =>
      "rejected(" ++ snapshotEscape code ++ "," ++ snapshotEscape detail ++ ")"

private def declLine (decl : ExtractDecl) : String :=
  "IR-FN\t" ++ rustValueIdent "generated" decl.rustName ++ "\t" ++
  joinWith "," (decl.args.map fingerprintArg) ++ "\t" ++
  fingerprintType decl.ret ++ "\t" ++
  fingerprintExtractExpr decl.body

private def findDeclByName (decls : List ExtractDecl) (rustName : String) : Option ExtractDecl :=
  decls.find? (fun decl => decl.rustName == rustName)

private def orderedDecls (decls : List ExtractDecl) : List ExtractDecl :=
  let lowered := decls.filterMap (fun decl =>
    match lowerDecl? decl with
    | .ok funDecl => some funDecl
    | .error _ => none)
  let orderedNames := orderFunctionsByDeps lowered |>.map (fun f => f.name)
  orderedNames.filterMap (findDeclByName decls)

/-- Text snapshot of the extractor-owned mandatory ExtractIR stage. -/
def extractIRSnapshot (decls : List ExtractDecl) : String :=
  let ordered := orderedDecls decls
  joinWith "\n" (
    [ "FORMAT\t" ++ extractIRFormat,
      "ARCH\tdirect-lean-emits-rust",
      "FN_COUNT\t" ++ toString ordered.length ] ++
    ordered.map declLine
  ) ++ "\n"

/-- Recursor recognition metadata captured before surface lowering. -/
structure RecursorMetadata where
  family : String
  sourceConstant : String
  loweredFeature : FeatureTag
  deriving Repr, BEq

/-- Resolved typeclass dictionary metadata captured before erasure/specialization. -/
structure DictionaryMetadata where
  className : String
  instanceName : String
  status : String
  deriving Repr, BEq

/-- Normalized declaration metadata used by reports and corpus diagnostics. -/
structure DeclarationMetadata where
  source : String
  rustName : String
  sourceSpan : LeanRustCore.Diagnostics.SourceSpan
  status : String
  erasedBinderCount : Nat
  features : List String
  recognizedRecursors : List RecursorMetadata
  dictionaries : List DictionaryMetadata
  nextFeature : String
  deriving Repr, BEq

/-- Build metadata for a supported checked surface declaration. -/
def metadataForSurfaceFun (source : String) (f : SurfaceFun) : DeclarationMetadata :=
  { source := source,
    rustName := f.name,
    sourceSpan := LeanRustCore.Diagnostics.SourceSpan.unknown source,
    status := "supported",
    erasedBinderCount := 0,
    features := functionFeatures f,
    recognizedRecursors := [],
    dictionaries := [],
    nextFeature := "none" }

/-- Build metadata for a rejected declaration. -/
def unsupportedMetadata (source rustName reason nextFeature : String) : DeclarationMetadata :=
  { source := source,
    rustName := rustName,
    sourceSpan := LeanRustCore.Diagnostics.SourceSpan.unknown source,
    status := reason,
    erasedBinderCount := 0,
    features := [featureTagName .unsupported],
    recognizedRecursors := [],
    dictionaries := [],
    nextFeature := nextFeature }

/-- Human-readable summary recorded in validation/proof reports. -/
def extractIRSummary : String :=
  "ExtractIR is an explicit pre-Surface stage carrying source spans, erased binders, recursor metadata, resolved dictionaries, feature tags, and next-feature diagnostics; only discharged SurfaceExpr nodes may reach Rust emission"

end LeanRustCore.ExtractIR
