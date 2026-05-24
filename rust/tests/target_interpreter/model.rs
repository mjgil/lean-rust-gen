use std::collections::BTreeMap;

use lean_rust_core_generated::*;
use lean_rust_core_validate::{parse_target_validation_functions, TargetValidationFunction};
use num_bigint::{BigInt, BigUint};

pub const TARGET_VALIDATION_SNAPSHOT: &str = include_str!("../../target-validation.txt");

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum UnaryFnU32 {
    Inc,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Value {
    Unit,
    Bool(bool),
    U32(u32),
    U64(u64),
    I32(i32),
    I64(i64),
    Char(char),
    String(String),
    Nat(BigUint),
    Int(BigInt),
    VecU32(Vec<u32>),
    OptionU32(Option<u32>),
    OptionU64(Option<u64>),
    OptionStep(Option<Step>),
    NestedOptionU32(Option<Option<u32>>),
    ResultU32U32(Result<u32, u32>),
    ResultU32String(Result<u32, String>),
    ResultU32OptionU32(Result<u32, Option<u32>>),
    ResultOptionU32U32(Result<Option<u32>, u32>),
    ProdU32((u32, u32)),
    Point(Point),
    Ordering(Ordering),
    Step(Step),
    Choice(Choice),
    PairchoiceU32String(PairchoiceU32String),
    PairboxU32String(PairboxU32String),
    PairboxStringU32(PairboxStringU32),
    BoxedU32(BoxedU32),
    BoundedProof(BoundedProof),
    AddDeltaEnv(AddDeltaU32Env),
    NestedpayloadU32String(NestedpayloadU32String),
    TaggedU32(TaggedU32),
    BinaryTreeU32(BinaryTreeU32),
    ExprU32(ExprU32),
    U32FnCase(U32FnCase),
    UnaryFnU32(UnaryFnU32),
    Boxed(Box<Value>),
}

pub type FunctionMap = BTreeMap<String, TargetValidationFunction>;
pub type Env = BTreeMap<String, Value>;

pub fn parse_snapshot_functions() -> Vec<TargetValidationFunction> {
    parse_target_validation_functions(TARGET_VALIDATION_SNAPSHOT)
        .expect("target-validation snapshot should parse")
}

pub fn function_map(functions: &[TargetValidationFunction]) -> FunctionMap {
    functions
        .iter()
        .cloned()
        .map(|function| (function.name.clone(), function))
        .collect()
}

pub fn sample_args_for(function: &TargetValidationFunction) -> Result<Vec<Value>, String> {
    function
        .args
        .iter()
        .map(|arg| sample_value_for(&arg.name, &arg.ty))
        .collect()
}

fn sample_value_for(name: &str, ty: &str) -> Result<Value, String> {
    Ok(match ty {
        "()" => Value::Unit,
        "bool" => Value::Bool(!matches!(name, "use_double")),
        "u32" => match name {
            "fallback" => Value::U32(7),
            "delta" => Value::U32(5),
            "dx" => Value::U32(2),
            "n" => Value::U32(5),
            "i" => Value::U32(7),
            "amount" => Value::U32(41),
            "when_false" | "right" | "y" | "hi" => Value::U32(50),
            "lo" => Value::U32(10),
            "b" => Value::U32(2),
            _ => Value::U32(40),
        },
        "u64" => match name {
            "fallback" => Value::U64(7),
            _ => Value::U64(40),
        },
        "i32" => Value::I32(-7),
        "i64" => Value::I64(-7),
        "char" => Value::Char('z'),
        "String" => Value::String(String::from("lean")),
        "Vec<u32>" => {
            if name == "ys" {
                Value::VecU32(vec![3, 4])
            } else {
                Value::VecU32(vec![0, 1, 2])
            }
        }
        "Option<u32>" => Value::OptionU32(Some(41)),
        "Option<u64>" => Value::OptionU64(Some(41)),
        "Option<Step>" => Value::OptionStep(Some(step_jump(41))),
        "Result<u32, u32>" => Value::ResultU32U32(Ok(41)),
        "(u32, u32)" => Value::ProdU32((40, 2)),
        "num_bigint::BigUint" => match name {
            "b" => Value::Nat(BigUint::from(2u32)),
            _ => Value::Nat(BigUint::from(40u32)),
        },
        "num_bigint::BigInt" => match name {
            "b" => Value::Int(BigInt::from(5i32)),
            _ => Value::Int(BigInt::from(-7i32)),
        },
        "Point" => Value::Point(make_point(40, 2)),
        "Step" => Value::Step(step_jump(41)),
        "Choice" => Value::Choice(Choice::First),
        "PairchoiceU32String" => Value::PairchoiceU32String(pair_choice_left_u32_string(41)),
        "PairboxU32String" => {
            Value::PairboxU32String(pair_box_make_u32_string(41, String::from("lean")))
        }
        "BoxedU32" => Value::BoxedU32(boxed_u32(41)),
        "BoundedProof" => Value::BoundedProof(bounded_proof_make_u32(41)),
        "NestedpayloadU32String" => Value::NestedpayloadU32String(nested_payload_ok_u32_string(41)),
        "TaggedU32" => Value::TaggedU32(tagged_present_u32(41)),
        "BinaryTreeU32" => {
            Value::BinaryTreeU32(tree_node_u32(tree_leaf_u32(()), 41, tree_leaf_u32(())))
        }
        "ExprU32" => Value::ExprU32(expr_add_u32(expr_lit_u32(40), expr_lit_u32(2))),
        "U32FnCase" => Value::U32FnCase(U32FnCase::Add(5)),
        "fn(u32) -> u32" => Value::UnaryFnU32(UnaryFnU32::Inc),
        other => {
            return Err(format!(
                "no target-interpreter sample value for type {other}"
            ))
        }
    })
}

pub fn v_unit(_: ()) -> Value {
    Value::Unit
}

pub fn v_bool(value: bool) -> Value {
    Value::Bool(value)
}

pub fn v_u32(value: u32) -> Value {
    Value::U32(value)
}

pub fn v_u64(value: u64) -> Value {
    Value::U64(value)
}

pub fn v_i32(value: i32) -> Value {
    Value::I32(value)
}

pub fn v_i64(value: i64) -> Value {
    Value::I64(value)
}

pub fn v_char(value: char) -> Value {
    Value::Char(value)
}

pub fn v_string(value: String) -> Value {
    Value::String(value)
}

pub fn v_nat(value: BigUint) -> Value {
    Value::Nat(value)
}

pub fn v_int(value: BigInt) -> Value {
    Value::Int(value)
}

pub fn v_vec_u32(value: Vec<u32>) -> Value {
    Value::VecU32(value)
}

pub fn v_option_u32(value: Option<u32>) -> Value {
    Value::OptionU32(value)
}

pub fn v_nested_option_u32(value: Option<Option<u32>>) -> Value {
    Value::NestedOptionU32(value)
}

pub fn v_result_u32_u32(value: Result<u32, u32>) -> Value {
    Value::ResultU32U32(value)
}

pub fn v_result_u32_option_u32(value: Result<u32, Option<u32>>) -> Value {
    Value::ResultU32OptionU32(value)
}

pub fn v_result_option_u32_u32(value: Result<Option<u32>, u32>) -> Value {
    Value::ResultOptionU32U32(value)
}

pub fn v_prod_u32(value: (u32, u32)) -> Value {
    Value::ProdU32(value)
}

pub fn v_point(value: Point) -> Value {
    Value::Point(value)
}

pub fn v_ordering(value: Ordering) -> Value {
    Value::Ordering(value)
}

pub fn v_step(value: Step) -> Value {
    Value::Step(value)
}

pub fn v_pairchoice_u32_string(value: PairchoiceU32String) -> Value {
    Value::PairchoiceU32String(value)
}

pub fn v_pairbox_u32_string(value: PairboxU32String) -> Value {
    Value::PairboxU32String(value)
}

pub fn v_pairbox_string_u32(value: PairboxStringU32) -> Value {
    Value::PairboxStringU32(value)
}

pub fn v_boxed_u32(value: BoxedU32) -> Value {
    Value::BoxedU32(value)
}

pub fn v_bounded_proof(value: BoundedProof) -> Value {
    Value::BoundedProof(value)
}

pub fn v_nestedpayload_u32_string(value: NestedpayloadU32String) -> Value {
    Value::NestedpayloadU32String(value)
}

pub fn v_tagged_u32(value: TaggedU32) -> Value {
    Value::TaggedU32(value)
}

pub fn v_binary_tree_u32(value: BinaryTreeU32) -> Value {
    Value::BinaryTreeU32(value)
}

pub fn v_expr_u32(value: ExprU32) -> Value {
    Value::ExprU32(value)
}

pub fn as_unit(value: &Value) -> Result<(), String> {
    match value {
        Value::Unit => Ok(()),
        other => Err(format!("expected unit, found {other:?}")),
    }
}

pub fn as_bool(value: &Value) -> Result<bool, String> {
    match value {
        Value::Bool(value) => Ok(*value),
        other => Err(format!("expected bool, found {other:?}")),
    }
}

pub fn as_u32(value: &Value) -> Result<u32, String> {
    match value {
        Value::U32(value) => Ok(*value),
        other => Err(format!("expected u32, found {other:?}")),
    }
}

pub fn as_u64(value: &Value) -> Result<u64, String> {
    match value {
        Value::U64(value) => Ok(*value),
        other => Err(format!("expected u64, found {other:?}")),
    }
}

pub fn as_i32(value: &Value) -> Result<i32, String> {
    match value {
        Value::I32(value) => Ok(*value),
        other => Err(format!("expected i32, found {other:?}")),
    }
}

pub fn as_i64(value: &Value) -> Result<i64, String> {
    match value {
        Value::I64(value) => Ok(*value),
        other => Err(format!("expected i64, found {other:?}")),
    }
}

pub fn as_char(value: &Value) -> Result<char, String> {
    match value {
        Value::Char(value) => Ok(*value),
        other => Err(format!("expected char, found {other:?}")),
    }
}

pub fn as_string(value: &Value) -> Result<String, String> {
    match value {
        Value::String(value) => Ok(value.clone()),
        other => Err(format!("expected string, found {other:?}")),
    }
}

pub fn as_nat(value: &Value) -> Result<BigUint, String> {
    match value {
        Value::Nat(value) => Ok(value.clone()),
        other => Err(format!("expected BigUint, found {other:?}")),
    }
}

pub fn as_int(value: &Value) -> Result<BigInt, String> {
    match value {
        Value::Int(value) => Ok(value.clone()),
        other => Err(format!("expected BigInt, found {other:?}")),
    }
}

pub fn as_vec_u32(value: &Value) -> Result<Vec<u32>, String> {
    match value {
        Value::VecU32(value) => Ok(value.clone()),
        other => Err(format!("expected Vec<u32>, found {other:?}")),
    }
}

pub fn as_option_u32(value: &Value) -> Result<Option<u32>, String> {
    match value {
        Value::OptionU32(value) => Ok(*value),
        other => Err(format!("expected Option<u32>, found {other:?}")),
    }
}

pub fn as_option_u64(value: &Value) -> Result<Option<u64>, String> {
    match value {
        Value::OptionU64(value) => Ok(*value),
        other => Err(format!("expected Option<u64>, found {other:?}")),
    }
}

pub fn as_option_step(value: &Value) -> Result<Option<Step>, String> {
    match value {
        Value::OptionStep(value) => Ok(value.clone()),
        other => Err(format!("expected Option<Step>, found {other:?}")),
    }
}

pub fn as_result_u32_u32(value: &Value) -> Result<Result<u32, u32>, String> {
    match value {
        Value::ResultU32U32(value) => Ok(*value),
        other => Err(format!("expected Result<u32, u32>, found {other:?}")),
    }
}

pub fn as_prod_u32(value: &Value) -> Result<(u32, u32), String> {
    match value {
        Value::ProdU32(value) => Ok(*value),
        other => Err(format!("expected (u32, u32), found {other:?}")),
    }
}

pub fn as_point(value: &Value) -> Result<Point, String> {
    match value {
        Value::Point(value) => Ok(value.clone()),
        other => Err(format!("expected Point, found {other:?}")),
    }
}

pub fn as_step(value: &Value) -> Result<Step, String> {
    match value {
        Value::Step(value) => Ok(value.clone()),
        other => Err(format!("expected Step, found {other:?}")),
    }
}

pub fn as_choice(value: &Value) -> Result<Choice, String> {
    match value {
        Value::Choice(value) => Ok(value.clone()),
        other => Err(format!("expected Choice, found {other:?}")),
    }
}

pub fn as_pairchoice_u32_string(value: &Value) -> Result<PairchoiceU32String, String> {
    match value {
        Value::PairchoiceU32String(value) => Ok(value.clone()),
        other => Err(format!("expected PairchoiceU32String, found {other:?}")),
    }
}

pub fn as_pairbox_u32_string(value: &Value) -> Result<PairboxU32String, String> {
    match value {
        Value::PairboxU32String(value) => Ok(value.clone()),
        other => Err(format!("expected PairboxU32String, found {other:?}")),
    }
}

pub fn as_boxed_u32(value: &Value) -> Result<BoxedU32, String> {
    match value {
        Value::BoxedU32(value) => Ok(value.clone()),
        other => Err(format!("expected BoxedU32, found {other:?}")),
    }
}

pub fn as_bounded_proof(value: &Value) -> Result<BoundedProof, String> {
    match value {
        Value::BoundedProof(value) => Ok(value.clone()),
        other => Err(format!("expected BoundedProof, found {other:?}")),
    }
}

pub fn as_nestedpayload_u32_string(value: &Value) -> Result<NestedpayloadU32String, String> {
    match value {
        Value::NestedpayloadU32String(value) => Ok(value.clone()),
        other => Err(format!("expected NestedpayloadU32String, found {other:?}")),
    }
}

pub fn as_tagged_u32(value: &Value) -> Result<TaggedU32, String> {
    match value {
        Value::TaggedU32(value) => Ok(value.clone()),
        other => Err(format!("expected TaggedU32, found {other:?}")),
    }
}

pub fn as_binary_tree_u32(value: &Value) -> Result<BinaryTreeU32, String> {
    match value {
        Value::BinaryTreeU32(value) => Ok(value.clone()),
        other => Err(format!("expected BinaryTreeU32, found {other:?}")),
    }
}

pub fn as_expr_u32(value: &Value) -> Result<ExprU32, String> {
    match value {
        Value::ExprU32(value) => Ok(value.clone()),
        other => Err(format!("expected ExprU32, found {other:?}")),
    }
}

pub fn as_u32_fn_case(value: &Value) -> Result<U32FnCase, String> {
    match value {
        Value::U32FnCase(value) => Ok(value.clone()),
        other => Err(format!("expected U32FnCase, found {other:?}")),
    }
}

pub fn as_unary_fn_u32(value: &Value) -> Result<UnaryFnU32, String> {
    match value {
        Value::UnaryFnU32(value) => Ok(value.clone()),
        other => Err(format!("expected unary fn(u32) -> u32, found {other:?}")),
    }
}

pub fn as_fn_u32(value: &Value) -> Result<fn(u32) -> u32, String> {
    match as_unary_fn_u32(value)? {
        UnaryFnU32::Inc => Ok(inc_u32),
    }
}
