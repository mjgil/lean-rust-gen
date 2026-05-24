import LeanRustCore.Surface
import LeanRustCore.EmitRust

namespace LeanRustCore.GenericEmission

/-!
Rows 23 and 25: parameterized data and final Rust-generic policy.

The completed design keeps the default generated lane monomorphization-only.
Parameterized Lean structures/enums are admitted after every type parameter has a
concrete `RType` substitution and the generated Rust declaration has a stable
monomorphic name.  Rust generic emission is therefore a documented, explicit
non-default future lane rather than an accidental partially supported feature.
-/

inductive GenericLane where
  | monomorphizedDefault
  | rustGenericFuture
  deriving Repr, BEq, DecidableEq

structure TypeParameter where
  name : String
  deriving Repr, BEq

structure TypeSubstitution where
  parameter : String
  replacement : RType
  deriving Repr, BEq

structure ParameterizedDataShape where
  leanName : String
  rustStem : String
  parameters : List TypeParameter
  fields : List (String × RType)
  variants : List (String × List RType)
  deriving Repr, BEq

structure MonomorphizedDataShape where
  leanName : String
  rustName : String
  lane : GenericLane
  substitutions : List TypeSubstitution
  fields : List (String × RType)
  variants : List (String × List RType)
  deriving Repr, BEq

private partial def findSubstitution (name : String) : List TypeSubstitution → Option RType
  | [] => none
  | sub :: rest => if sub.parameter == name then some sub.replacement else findSubstitution name rest

/-- Replace parameter placeholders encoded as recursive names `param:<name>` inside an `RType`. -/
partial def substituteType (subs : List TypeSubstitution) : RType → RType
  | .option t => .option (substituteType subs t)
  | .result ok err => .result (substituteType subs ok) (substituteType subs err)
  | .list t => .list (substituteType subs t)
  | .array t => .array (substituteType subs t)
  | .prod a b => .prod (substituteType subs a) (substituteType subs b)
  | .sum a b => .sum (substituteType subs a) (substituteType subs b)
  | .func a b => .func (substituteType subs a) (substituteType subs b)
  | .boxed t => .boxed (substituteType subs t)
  | .subtype t => .subtype (substituteType subs t)
  | .vector t n => .vector (substituteType subs t) n
  | .struct name fields => .struct name (fields.map (fun f => (f.1, substituteType subs f.2)))
  | .enum name variants => .enum name (variants.map (fun v => (v.1, v.2.map (substituteType subs))))
  | .recursive name =>
      match name.splitOn ":" with
      | ["param", p] => match findSubstitution p subs with | some ty => ty | none => .recursive name
      | _ => .recursive name
  | other => other

private def typeSuffix : RType → String
  | .unit => "unit"
  | .bool => "bool"
  | .ordering => "ordering"
  | .nat => "nat"
  | .int => "int"
  | .u32 => "u32"
  | .u64 => "u64"
  | .i32 => "i32"
  | .i64 => "i64"
  | .char => "char"
  | .string => "string"
  | .option t => "option_" ++ typeSuffix t
  | .result ok err => "result_" ++ typeSuffix ok ++ "_" ++ typeSuffix err
  | .list t => "list_" ++ typeSuffix t
  | .array t => "array_" ++ typeSuffix t
  | .prod a b => "prod_" ++ typeSuffix a ++ "_" ++ typeSuffix b
  | .sum a b => "sum_" ++ typeSuffix a ++ "_" ++ typeSuffix b
  | .func a b => "fn_" ++ typeSuffix a ++ "_" ++ typeSuffix b
  | .boxed t => "box_" ++ typeSuffix t
  | .recursive n => rustTypeIdent n
  | .subtype t => "subtype_" ++ typeSuffix t
  | .fin n => "fin" ++ toString n
  | .vector t n => "vector" ++ toString n ++ "_" ++ typeSuffix t
  | .struct n _ => rustTypeIdent n
  | .enum n _ => rustTypeIdent n

private def rustMonoName (stem : String) (subs : List TypeSubstitution) : String :=
  rustTypeIdent (stem ++ "__" ++ joinWith "__" (subs.map (fun s => s.parameter ++ "_" ++ typeSuffix s.replacement)))

/-- Instantiate a parameterized data declaration after all parameters have concrete substitutions. -/
def monomorphizeDataShape (shape : ParameterizedDataShape) (subs : List TypeSubstitution) : Except String MonomorphizedDataShape :=
  let missing := shape.parameters.filter (fun p => (findSubstitution p.name subs).isNone)
  if !missing.isEmpty then
    Except.error ("missing substitutions for " ++ joinWith ", " (missing.map (fun p => p.name)))
  else
    Except.ok {
      leanName := shape.leanName,
      rustName := rustMonoName shape.rustStem subs,
      lane := .monomorphizedDefault,
      substitutions := subs,
      fields := shape.fields.map (fun f => (f.1, substituteType subs f.2)),
      variants := shape.variants.map (fun v => (v.1, v.2.map (substituteType subs)))
    }

/-- Final policy: Rust generic declarations are intentionally rejected in the default lane. -/
def rustGenericEmissionAllowedByDefault : Bool := false

/-- Examples used by docs/tests for rows 23 and 25. -/
def parameterizedFixture : ParameterizedDataShape := {
  leanName := "LeanRustCore.Examples.PairBox",
  rustStem := "PairBox",
  parameters := [{ name := "A" }, { name := "B" }],
  fields := [("left", .recursive "param:A"), ("right", .recursive "param:B")],
  variants := []
}

def parameterizedFixtureU32String : Except String MonomorphizedDataShape :=
  monomorphizeDataShape parameterizedFixture [
    { parameter := "A", replacement := .u32 },
    { parameter := "B", replacement := .string }
  ]

/-- Human-readable summary for reports. -/
def genericEmissionSummary : String :=
  "rows 23/25 complete: parameterized Lean data is accepted through deterministic concrete monomorphization; Rust generic emission is explicitly disabled in the safe default lane until a verified generic/bounds lane is added"

end LeanRustCore.GenericEmission
