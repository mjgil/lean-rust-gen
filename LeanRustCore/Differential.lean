import LeanRustCore.Examples

namespace LeanRustCore.Differential

open LeanRustCore
open LeanRustCore.Examples

/-!
Step 7/8 differential fixtures, extended by steps 3/4.

The first group keeps the original proof-carrying `IR.eval` assertions.  The
second group now uses `LeanRustCore.Surface.evalSurfaceFun`, so structs, enums,
`Result`, monomorphized exports, payload matches, and first-order calls are
checked by the same surface semantics consumed by the Rust emitter.
-/

structure RustAssertion where
  expression : String
  expected : String
  deriving Repr, BEq

private def rustU32 (n : Nat) : String :=
  Nat.toString (u32Wrap n) ++ "u32"

private def rustU64 (n : Nat) : String :=
  Nat.toString (u64Wrap n) ++ "u64"

private def rustI32 (n : Int) : String :=
  toString n ++ "i32"

private def rustI64 (n : Int) : String :=
  toString n ++ "i64"

private def rustBool (b : Bool) : String :=
  if b then "true" else "false"

private partial def rustSurfaceValue : SurfaceValue → String
  | .unit => "()"
  | .bool b => rustBool b
  | .u32 n => rustU32 n
  | .u64 n => rustU64 n
  | .i32 n => rustI32 n
  | .i64 n => rustI64 n
  | .optionNone ty => "None::<" ++ rustType ty ++ ">"
  | .optionSome value => "Some(" ++ rustSurfaceValue value ++ ")"
  | .resultOk value => "Ok(" ++ rustSurfaceValue value ++ ")"
  | .resultErr value => "Err(" ++ rustSurfaceValue value ++ ")"
  | .structVal name fields =>
      let rendered := fields.map (fun field => field.1 ++ ": " ++ rustSurfaceValue field.2)
      name ++ " { " ++ joinWith ", " rendered ++ " }"
  | .enumVal name variant payload =>
      let renderedPayload := if payload.isEmpty then "" else "(" ++ joinWith ", " (payload.map rustSurfaceValue) ++ ")"
      name ++ "::" ++ rustVariantName variant ++ renderedPayload

private def clampExpected (lo hi x : Nat) : String :=
  rustU32 (eval clampBody { lo := lo, hi := hi, x := x })

private def maxExpected (a b : Nat) : String :=
  rustU32 (eval maxBody { a := a, b := b })

private def nonzeroExpected (x : Nat) : String :=
  rustBool (eval nonzeroBody { x := x })

private def addExpected (a b : Nat) : String :=
  rustU32 (eval addBody { a := a, b := b })

private def bumpExpected (x : Nat) : String :=
  rustU32 (eval boundedBumpBody { x := x })

private def optionDefaultExpected (x : Option Nat) (fallback : Nat) : String :=
  rustU32 (eval optionDefaultBody { x := x, fallback := fallback })

private def assertion (expression expected : String) : RustAssertion :=
  { expression := expression, expected := expected }

/-- Differential assertions whose expectations are rendered from proof-carrying Lean IR evaluator results. -/
def evaluatorAssertions : List RustAssertion := [
  assertion "clamp_u32(10, 20, 5)" (clampExpected 10 20 5),
  assertion "clamp_u32(10, 20, 25)" (clampExpected 10 20 25),
  assertion "clamp_u32(10, 20, 15)" (clampExpected 10 20 15),
  assertion "max_u32(3, 8)" (maxExpected 3 8),
  assertion "max_u32(8, 3)" (maxExpected 8 3),
  assertion "is_nonzero_u32(0)" (nonzeroExpected 0),
  assertion "is_nonzero_u32(7)" (nonzeroExpected 7),
  assertion "add_u32(u32::MAX, 1)" (addExpected (u32Modulus - 1) 1),
  assertion "add_u32(40, 2)" (addExpected 40 2),
  assertion "bounded_bump_u32(0)" (bumpExpected 0),
  assertion "bounded_bump_u32(9)" (bumpExpected 9),
  assertion "bounded_bump_u32(10)" (bumpExpected 10),
  assertion "bounded_bump_u32(u32::MAX)" (bumpExpected (u32Modulus - 1)),
  assertion "option_default_u32(None, 8)" (optionDefaultExpected none 8),
  assertion "option_default_u32(Some(3), 8)" (optionDefaultExpected (some 3) 8)
]

private def pointTy : RType :=
  .struct "Point" [("x", .u32), ("y", .u32)]

private def choiceTy : RType :=
  .enum "Choice" [("first", []), ("second", [])]

private def stepTy : RType :=
  .enum "Step" [("stay", []), ("jump", [.u32])]

private def sfAddU64 : SurfaceFun := {
  name := "add_u64",
  args := [("a", .u64), ("b", .u64)],
  ret := .u64,
  body := .add .u64 (.var "a") (.var "b")
}

private def sfIncU32 : SurfaceFun := {
  name := "inc_u32",
  args := [("x", .u32)],
  ret := .u32,
  body := .add .u32 (.var "x") (.litU32 1)
}

private def sfIncTwiceU32 : SurfaceFun := {
  name := "inc_twice_u32",
  args := [("x", .u32)],
  ret := .u32,
  body := .call "inc_u32" [.u32] .u32 [
    .call "inc_u32" [.u32] .u32 [.var "x"]
  ]
}

private def sfBoolMatchU32 : SurfaceFun := {
  name := "bool_match_u32",
  args := [("flag", .bool), ("when_true", .u32), ("when_false", .u32)],
  ret := .u32,
  body := .matchBool (.var "flag") (.var "when_true") (.var "when_false")
}

private def sfSomeU32 : SurfaceFun := {
  name := "some_u32",
  args := [("x", .u32)],
  ret := .option .u32,
  body := .optionSome (.var "x")
}

private def sfNoneU32 : SurfaceFun := {
  name := "none_u32",
  args := [("_x", .unit)],
  ret := .option .u32,
  body := .optionNone .u32
}

private def sfOptionDefaultU32 : SurfaceFun := {
  name := "option_default_u32",
  args := [("x", .option .u32), ("fallback", .u32)],
  ret := .u32,
  body := .matchOption (.var "x") (.var "fallback") "value" (.var "value")
}

private def sfResultOkU32 : SurfaceFun := {
  name := "result_ok_u32",
  args := [("x", .u32)],
  ret := .result .u32 .u32,
  body := .resultOk .u32 (.var "x")
}

private def sfResultErrU32 : SurfaceFun := {
  name := "result_err_u32",
  args := [("e", .u32)],
  ret := .result .u32 .u32,
  body := .resultErr .u32 (.var "e")
}

private def sfChooseByEnum : SurfaceFun := {
  name := "choose_by_enum",
  args := [("choice", choiceTy), ("left", .u32), ("right", .u32)],
  ret := .u32,
  body := .matchEnum choiceTy (.var "choice") [
    ("first", ([], .var "left")),
    ("second", ([], .var "right"))
  ]
}

private def sfMakePoint : SurfaceFun := {
  name := "make_point",
  args := [("x", .u32), ("y", .u32)],
  ret := pointTy,
  body := .structLit pointTy [("x", .var "x"), ("y", .var "y")]
}

private def sfPointX : SurfaceFun := {
  name := "point_x",
  args := [("p", pointTy)],
  ret := .u32,
  body := .field (.var "p") "x"
}

private def sfPointY : SurfaceFun := {
  name := "point_y",
  args := [("p", pointTy)],
  ret := .u32,
  body := .field (.var "p") "y"
}

private def sfShiftPointX : SurfaceFun := {
  name := "shift_point_x",
  args := [("p", pointTy), ("dx", .u32)],
  ret := pointTy,
  body := .structLit pointTy [
    ("x", .add .u32 (.field (.var "p") "x") (.var "dx")),
    ("y", .field (.var "p") "y")
  ]
}

private def sfStepStay : SurfaceFun := {
  name := "step_stay",
  args := [("_x", .unit)],
  ret := stepTy,
  body := .enumVariant stepTy "stay" []
}

private def sfStepJump : SurfaceFun := {
  name := "step_jump",
  args := [("amount", .u32)],
  ret := stepTy,
  body := .enumVariant stepTy "jump" [.var "amount"]
}

private def sfStepAmountOr : SurfaceFun := {
  name := "step_amount_or",
  args := [("s", stepTy), ("fallback", .u32)],
  ret := .u32,
  body := .matchEnum stepTy (.var "s") [
    ("stay", ([], .var "fallback")),
    ("jump", (["amount"], .var "amount"))
  ]
}

private def sfStepAmountPlusOneOr : SurfaceFun := {
  name := "step_amount_plus_one_or",
  args := [("s", stepTy), ("fallback", .u32)],
  ret := .u32,
  body := .matchEnum stepTy (.var "s") [
    ("stay", ([], .var "fallback")),
    ("jump", (["amount"], .add .u32 (.var "amount") (.litU32 1)))
  ]
}

private def sfNestedNoneU32 : SurfaceFun := {
  name := "nested_none_u32",
  args := [("_x", .unit)],
  ret := .option (.option .u32),
  body := .optionSome (.optionNone .u32)
}

private def sfResultOkNoneU32 : SurfaceFun := {
  name := "result_ok_none_u32",
  args := [("_x", .unit)],
  ret := .result (.option .u32) .u32,
  body := .resultOk .u32 (.optionNone .u32)
}

private def sfResultErrSomeU32 : SurfaceFun := {
  name := "result_err_some_u32",
  args := [("e", .u32)],
  ret := .result .u32 (.option .u32),
  body := .resultErr .u32 (.optionSome (.var "e"))
}

private def sfIdentityU64 : SurfaceFun := {
  name := "identity_u64",
  args := [("x", .u64)],
  ret := .u64,
  body := .var "x"
}

private def sfChooseGenericU32 : SurfaceFun := {
  name := "choose_generic_u32",
  args := [("flag", .bool), ("when_true", .u32), ("when_false", .u32)],
  ret := .u32,
  body := .ite (.var "flag") (.var "when_true") (.var "when_false")
}

private def sfOptionDefaultU64 : SurfaceFun := {
  name := "option_default_u64",
  args := [("x", .option .u64), ("fallback", .u64)],
  ret := .u64,
  body := .matchOption (.var "x") (.var "fallback") "value" (.var "value")
}

private def sfGenericIdentityU32 : SurfaceFun := {
  name := "generic_identity__u32",
  args := [("x", .u32)],
  ret := .u32,
  body := .var "x"
}

private def sfGenericChoosePoint : SurfaceFun := {
  name := "generic_choose__point",
  args := [("flag", .bool), ("when_true", pointTy), ("when_false", pointTy)],
  ret := pointTy,
  body := .ite (.var "flag") (.var "when_true") (.var "when_false")
}

private def sfGenericOptionDefaultStep : SurfaceFun := {
  name := "generic_option_default__step",
  args := [("x", .option stepTy), ("fallback", stepTy)],
  ret := stepTy,
  body := .matchOption (.var "x") (.var "fallback") "value" (.var "value")
}

private def sfAutoIdentityU32 : SurfaceFun := {
  name := "auto_identity_u32",
  args := [("x", .u32)],
  ret := .u32,
  body := .call "generic_identity__u32" [.u32] .u32 [.var "x"]
}

private def sfAutoChoosePoint : SurfaceFun := {
  name := "auto_choose_point",
  args := [("flag", .bool), ("left", pointTy), ("right", pointTy)],
  ret := pointTy,
  body := .call "generic_choose__point" [.bool, pointTy, pointTy] pointTy [.var "flag", .var "left", .var "right"]
}

private def sfAutoOptionDefaultStep : SurfaceFun := {
  name := "auto_option_default_step",
  args := [("x", .option stepTy), ("fallback", stepTy)],
  ret := stepTy,
  body := .call "generic_option_default__step" [.option stepTy, stepTy] stepTy [.var "x", .var "fallback"]
}

/-- Surface-level semantic fixtures covering the currently extracted declaration families. -/
def surfaceFixtureFunctions : List SurfaceFun := [
  sfAddU64,
  sfIncU32,
  sfIncTwiceU32,
  sfBoolMatchU32,
  sfSomeU32,
  sfNoneU32,
  sfOptionDefaultU32,
  sfResultOkU32,
  sfResultErrU32,
  sfChooseByEnum,
  sfMakePoint,
  sfPointX,
  sfPointY,
  sfShiftPointX,
  sfStepStay,
  sfStepJump,
  sfStepAmountOr,
  sfStepAmountPlusOneOr,
  sfNestedNoneU32,
  sfResultOkNoneU32,
  sfResultErrSomeU32,
  sfIdentityU64,
  sfChooseGenericU32,
  sfOptionDefaultU64,
  sfGenericIdentityU32,
  sfGenericChoosePoint,
  sfGenericOptionDefaultStep,
  sfAutoIdentityU32,
  sfAutoChoosePoint,
  sfAutoOptionDefaultStep
]

private def surfaceExpected (name : String) (args : List SurfaceValue) : String :=
  match lookupSurfaceFun? surfaceFixtureFunctions name with
  | none => "/* missing surface fixture: " ++ name ++ " */"
  | some f =>
      match evalSurfaceFun surfaceFixtureFunctions f args with
      | .ok value => rustSurfaceValue value
      | .error report => "/* surface evaluator error: " ++ report.detail ++ " */"

private def vU32 (n : Nat) : SurfaceValue := .u32 n
private def vU64 (n : Nat) : SurfaceValue := .u64 n
private def vUnit : SurfaceValue := .unit
private def vBool (b : Bool) : SurfaceValue := .bool b
private def vNone (ty : RType) : SurfaceValue := .optionNone ty
private def vSome (value : SurfaceValue) : SurfaceValue := .optionSome value
private def vChoice (variant : String) : SurfaceValue := .enumVal "Choice" variant []
private def vPoint (x y : Nat) : SurfaceValue := .structVal "Point" [("x", .u32 x), ("y", .u32 y)]
private def vStepStay : SurfaceValue := .enumVal "Step" "stay" []
private def vStepJump (amount : Nat) : SurfaceValue := .enumVal "Step" "jump" [.u32 amount]

/-- Additional cases whose expectations are computed by the checked `SurfaceExpr` evaluator. -/
def extractedDeclarationAssertions : List RustAssertion := [
  assertion "add_u64(u64::MAX, 1)" (surfaceExpected "add_u64" [vU64 (u64Modulus - 1), vU64 1]),
  assertion "bool_match_u32(true, 1, 2)" (surfaceExpected "bool_match_u32" [vBool true, vU32 1, vU32 2]),
  assertion "bool_match_u32(false, 1, 2)" (surfaceExpected "bool_match_u32" [vBool false, vU32 1, vU32 2]),
  assertion "some_u32(4)" (surfaceExpected "some_u32" [vU32 4]),
  assertion "none_u32(())" (surfaceExpected "none_u32" [vUnit]),
  assertion "option_default_u32(None, 8)" (surfaceExpected "option_default_u32" [vNone .u32, vU32 8]),
  assertion "option_default_u32(Some(3), 8)" (surfaceExpected "option_default_u32" [vSome (vU32 3), vU32 8]),
  assertion "result_ok_u32(5)" (surfaceExpected "result_ok_u32" [vU32 5]),
  assertion "result_err_u32(7)" (surfaceExpected "result_err_u32" [vU32 7]),
  assertion "choose_by_enum(Choice::First, 10, 20)" (surfaceExpected "choose_by_enum" [vChoice "first", vU32 10, vU32 20]),
  assertion "choose_by_enum(Choice::Second, 10, 20)" (surfaceExpected "choose_by_enum" [vChoice "second", vU32 10, vU32 20]),
  assertion "make_point(3, 4)" (surfaceExpected "make_point" [vU32 3, vU32 4]),
  assertion "point_x(Point { x: 8, y: 9 })" (surfaceExpected "point_x" [vPoint 8 9]),
  assertion "point_y(Point { x: 8, y: 9 })" (surfaceExpected "point_y" [vPoint 8 9]),
  assertion "shift_point_x(Point { x: u32::MAX, y: 7 }, 1)" (surfaceExpected "shift_point_x" [vPoint (u32Modulus - 1) 7, vU32 1]),
  assertion "step_stay(())" (surfaceExpected "step_stay" [vUnit]),
  assertion "step_jump(12)" (surfaceExpected "step_jump" [vU32 12]),
  assertion "step_amount_or(Step::Stay, 9)" (surfaceExpected "step_amount_or" [vStepStay, vU32 9]),
  assertion "step_amount_or(Step::Jump(12), 9)" (surfaceExpected "step_amount_or" [vStepJump 12, vU32 9]),
  assertion "step_amount_plus_one_or(Step::Stay, 7)" (surfaceExpected "step_amount_plus_one_or" [vStepStay, vU32 7]),
  assertion "step_amount_plus_one_or(Step::Jump(u32::MAX), 7)" (surfaceExpected "step_amount_plus_one_or" [vStepJump (u32Modulus - 1), vU32 7]),
  assertion "inc_u32(41)" (surfaceExpected "inc_u32" [vU32 41]),
  assertion "inc_u32(u32::MAX)" (surfaceExpected "inc_u32" [vU32 (u32Modulus - 1)]),
  assertion "inc_twice_u32(40)" (surfaceExpected "inc_twice_u32" [vU32 40]),
  assertion "inc_twice_u32(u32::MAX)" (surfaceExpected "inc_twice_u32" [vU32 (u32Modulus - 1)]),
  assertion "nested_none_u32(())" (surfaceExpected "nested_none_u32" [vUnit]),
  assertion "result_ok_none_u32(())" (surfaceExpected "result_ok_none_u32" [vUnit]),
  assertion "result_err_some_u32(44)" (surfaceExpected "result_err_some_u32" [vU32 44]),
  assertion "identity_u64(99)" (surfaceExpected "identity_u64" [vU64 99]),
  assertion "choose_generic_u32(true, 10, 20)" (surfaceExpected "choose_generic_u32" [vBool true, vU32 10, vU32 20]),
  assertion "choose_generic_u32(false, 10, 20)" (surfaceExpected "choose_generic_u32" [vBool false, vU32 10, vU32 20]),
  assertion "option_default_u64(None, 77)" (surfaceExpected "option_default_u64" [vNone .u64, vU64 77]),
  assertion "option_default_u64(Some(55), 77)" (surfaceExpected "option_default_u64" [vSome (vU64 55), vU64 77]),
  assertion "generic_identity__u32(11)" (surfaceExpected "generic_identity__u32" [vU32 11]),
  assertion "auto_identity_u32(12)" (surfaceExpected "auto_identity_u32" [vU32 12]),
  assertion "generic_choose__point(true, Point { x: 1, y: 2 }, Point { x: 3, y: 4 })" (surfaceExpected "generic_choose__point" [vBool true, vPoint 1 2, vPoint 3 4]),
  assertion "generic_choose__point(false, Point { x: 1, y: 2 }, Point { x: 3, y: 4 })" (surfaceExpected "generic_choose__point" [vBool false, vPoint 1 2, vPoint 3 4]),
  assertion "auto_choose_point(true, Point { x: 1, y: 2 }, Point { x: 3, y: 4 })" (surfaceExpected "auto_choose_point" [vBool true, vPoint 1 2, vPoint 3 4]),
  assertion "auto_choose_point(false, Point { x: 1, y: 2 }, Point { x: 3, y: 4 })" (surfaceExpected "auto_choose_point" [vBool false, vPoint 1 2, vPoint 3 4]),
  assertion "generic_option_default__step(None, Step::Stay)" (surfaceExpected "generic_option_default__step" [vNone stepTy, vStepStay]),
  assertion "generic_option_default__step(Some(Step::Jump(7)), Step::Stay)" (surfaceExpected "generic_option_default__step" [vSome (vStepJump 7), vStepStay]),
  assertion "auto_option_default_step(None, Step::Jump(5))" (surfaceExpected "auto_option_default_step" [vNone stepTy, vStepJump 5]),
  assertion "auto_option_default_step(Some(Step::Stay), Step::Jump(5))" (surfaceExpected "auto_option_default_step" [vSome vStepStay, vStepJump 5])
]

private def emitAssertion (a : RustAssertion) : String :=
  if a.expected == "true" then
    "    assert!(" ++ a.expression ++ ");"
  else if a.expected == "false" then
    "    assert!(!" ++ a.expression ++ ");"
  else
    "    assert_eq!(" ++ a.expression ++ ", " ++ a.expected ++ ");"

private def emitAssertionsTest (name : String) (assertions : List RustAssertion) : String :=
  "#[test]\nfn " ++ name ++ "() {\n" ++
  joinWith "\n" (assertions.map emitAssertion) ++
  "\n}\n"

/-- Rust integration-test source generated from the Lean differential fixtures. -/
def generatedDifferentialRustTests : String :=
  "// Generated by LeanRustCore.Differential. Do not edit by hand.\n" ++
  "// Expectations on the right-hand side are computed in Lean.\n\n" ++
  "use lean_rust_core_generated::*;\n\n" ++
  emitAssertionsTest "lean_ir_evaluator_matches_generated_rust" evaluatorAssertions ++
  "\n" ++
  emitAssertionsTest "surface_evaluator_matches_extracted_rust" extractedDeclarationAssertions

end LeanRustCore.Differential
