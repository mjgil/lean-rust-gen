use lean_rust_core_generated::*;

use super::model::Value;
use super::parse::{call_payload, split_top_args};

fn bare_binder(name: &str, value: Value) -> Option<Vec<(String, Value)>> {
    if name.is_empty()
        || !name
            .bytes()
            .all(|byte| byte == b'_' || byte.is_ascii_alphanumeric())
    {
        return None;
    }
    Some(vec![(name.to_string(), value)])
}

pub fn match_pattern_bindings(pattern: &str, value: &Value) -> Option<Vec<(String, Value)>> {
    match (pattern, value) {
        ("_", _) => Some(Vec::new()),
        ("true", Value::Bool(true)) | ("false", Value::Bool(false)) => Some(Vec::new()),
        ("None", Value::OptionU32(None))
        | ("None", Value::OptionU64(None))
        | ("None", Value::OptionStep(None)) => Some(Vec::new()),
        ("Choice::First", Value::Choice(Choice::First))
        | ("Choice::Second", Value::Choice(Choice::Second))
        | ("Step::Stay", Value::Step(Step::Stay))
        | ("TaggedU32::Missing", Value::TaggedU32(TaggedU32::Missing)) => Some(Vec::new()),
        ("Choice::First()", Value::Choice(Choice::First))
        | ("Choice::Second()", Value::Choice(Choice::Second))
        | ("Step::Stay()", Value::Step(Step::Stay))
        | ("TaggedU32::Missing()", Value::TaggedU32(TaggedU32::Missing))
        | ("Err", Value::ResultU32U32(Err(_)))
        | ("Err", Value::ResultU32OptionU32(Err(_)))
        | ("Ok", Value::ResultU32U32(Ok(_)))
        | ("Ok", Value::ResultOptionU32U32(Ok(_))) => Some(Vec::new()),
        _ => {
            if let Some(name) = call_payload(pattern, "varpat") {
                return Some(vec![(name.to_string(), value.clone())]);
            }
            if let (Some(inner), Value::OptionU32(Some(value))) =
                (call_payload(pattern, "Some"), value)
            {
                let name = call_payload(inner, "varpat")?;
                return Some(vec![(name.to_string(), Value::U32(*value))]);
            }
            if let (Some(inner), Value::OptionStep(Some(value))) =
                (call_payload(pattern, "Some"), value)
            {
                let name = call_payload(inner, "varpat")?;
                return Some(vec![(name.to_string(), Value::Step(value.clone()))]);
            }
            if let (Some(inner), Value::OptionU64(Some(value))) =
                (call_payload(pattern, "Some"), value)
            {
                let name = call_payload(inner, "varpat")?;
                return Some(vec![(name.to_string(), Value::U64(*value))]);
            }
            if let (Some(inner), Value::Step(Step::Jump(amount))) =
                (call_payload(pattern, "Step::Jump"), value)
            {
                let name = call_payload(inner, "varpat")?;
                return Some(vec![(name.to_string(), Value::U32(*amount))]);
            }
            if let (Some(inner), Value::TaggedU32(TaggedU32::Present(value))) =
                (call_payload(pattern, "TaggedU32::Present"), value)
            {
                let name = call_payload(inner, "varpat")?;
                return Some(vec![(name.to_string(), Value::U32(*value))]);
            }
            if let (Some(inner), Value::PairchoiceU32String(PairchoiceU32String::Left(value))) =
                (call_payload(pattern, "PairchoiceU32String::Left"), value)
            {
                let name = call_payload(inner, "varpat")?;
                return Some(vec![(name.to_string(), Value::U32(*value))]);
            }
            if let (Some(inner), Value::PairchoiceU32String(PairchoiceU32String::Right(value))) =
                (call_payload(pattern, "PairchoiceU32String::Right"), value)
            {
                let name = call_payload(inner, "varpat")?;
                return Some(vec![(name.to_string(), Value::String(value.clone()))]);
            }
            if pattern.starts_with('(') && pattern.ends_with(')') {
                let parts = split_top_args(&pattern[1..pattern.len() - 1]);
                if parts.len() != 2 {
                    return None;
                }
                let pair = match value {
                    Value::ProdU32((left, right)) => (Value::U32(*left), Value::U32(*right)),
                    Value::ProdUnitU32(right) => (Value::Unit, Value::U32(*right)),
                    Value::ProdResultUnitU32U32((left, right)) => {
                        (Value::ResultUnitU32(*left), Value::U32(*right))
                    }
                    Value::ProdResultU32U32U32((left, right)) => {
                        (Value::ResultU32U32(*left), Value::U32(*right))
                    }
                    _ => return None,
                };
                let mut bindings = match_pattern_bindings(parts[0], &pair.0)
                    .or_else(|| match_enum_bindings(parts[0], &pair.0))?;
                bindings.extend(
                    match_pattern_bindings(parts[1], &pair.1)
                        .or_else(|| match_enum_bindings(parts[1], &pair.1))?,
                );
                return Some(bindings);
            }
            None
        }
    }
}

pub fn match_enum_bindings(pattern: &str, value: &Value) -> Option<Vec<(String, Value)>> {
    match (pattern, value) {
        ("BinaryTreeU32::Leaf()", Value::BinaryTreeU32(BinaryTreeU32::Leaf)) => Some(Vec::new()),
        ("U32FnCase::Inc()", Value::U32FnCase(U32FnCase::Inc))
        | ("U32FnCase::Double()", Value::U32FnCase(U32FnCase::Double)) => Some(Vec::new()),
        _ => match (pattern, value) {
            _ if pattern.starts_with("Err(") && pattern.ends_with(')') => match value {
                Value::ResultUnitU32(Err(err)) => {
                    let binder = call_payload(pattern, "Err")?;
                    match_pattern_bindings(binder, &Value::U32(*err))
                        .or_else(|| bare_binder(binder, Value::U32(*err)))
                }
                Value::ResultU32U32(Err(err)) => {
                    let binder = call_payload(pattern, "Err")?;
                    match_pattern_bindings(binder, &Value::U32(*err))
                        .or_else(|| bare_binder(binder, Value::U32(*err)))
                }
                Value::ResultU32OptionU32(Err(err)) => {
                    let binder = call_payload(pattern, "Err")?;
                    match_pattern_bindings(binder, &Value::OptionU32(*err))
                        .or_else(|| bare_binder(binder, Value::OptionU32(*err)))
                }
                _ => None,
            },
            _ if pattern.starts_with("Ok(") && pattern.ends_with(')') => match value {
                Value::ResultUnitU32(Ok(())) => {
                    let binder = call_payload(pattern, "Ok")?;
                    match_pattern_bindings(binder, &Value::Unit)
                        .or_else(|| bare_binder(binder, Value::Unit))
                }
                Value::ResultU32U32(Ok(value)) => {
                    let binder = call_payload(pattern, "Ok")?;
                    match_pattern_bindings(binder, &Value::U32(*value))
                        .or_else(|| bare_binder(binder, Value::U32(*value)))
                }
                Value::ResultOptionU32U32(Ok(value)) => {
                    let binder = call_payload(pattern, "Ok")?;
                    match_pattern_bindings(binder, &Value::OptionU32(*value))
                        .or_else(|| bare_binder(binder, Value::OptionU32(*value)))
                }
                _ => None,
            },
            ("ExprU32::Lit(value)", Value::ExprU32(ExprU32::Lit(value))) => {
                Some(vec![(String::from("value"), Value::U32(*value))])
            }
            ("ExprU32::Add(left,right)", Value::ExprU32(ExprU32::Add(left, right))) => Some(vec![
                (
                    String::from("left"),
                    Value::Boxed(Box::new(Value::ExprU32((**left).clone()))),
                ),
                (
                    String::from("right"),
                    Value::Boxed(Box::new(Value::ExprU32((**right).clone()))),
                ),
            ]),
            (
                "BinaryTreeU32::Node(left,value,right)",
                Value::BinaryTreeU32(BinaryTreeU32::Node(left, value, right)),
            ) => Some(vec![
                (
                    String::from("left"),
                    Value::Boxed(Box::new(Value::BinaryTreeU32((**left).clone()))),
                ),
                (String::from("value"), Value::U32(*value)),
                (
                    String::from("right"),
                    Value::Boxed(Box::new(Value::BinaryTreeU32((**right).clone()))),
                ),
            ]),
            ("EvenNode::Terminal(value)", Value::EvenNode(EvenNode::Terminal(value))) => {
                Some(vec![(String::from("value"), Value::U32(*value))])
            }
            ("EvenNode::Step(value,next)", Value::EvenNode(EvenNode::Step(value, next))) => {
                Some(vec![
                    (String::from("value"), Value::U32(*value)),
                    (
                        String::from("next"),
                        Value::Boxed(Box::new(Value::OddNode((**next).clone()))),
                    ),
                ])
            }
            ("OddNode::Terminal(value)", Value::OddNode(OddNode::Terminal(value))) => {
                Some(vec![(String::from("value"), Value::U32(*value))])
            }
            ("OddNode::Step(value,next)", Value::OddNode(OddNode::Step(value, next))) => {
                Some(vec![
                    (String::from("value"), Value::U32(*value)),
                    (
                        String::from("next"),
                        Value::Boxed(Box::new(Value::EvenNode((**next).clone()))),
                    ),
                ])
            }
            ("U32FnCase::Add(delta)", Value::U32FnCase(U32FnCase::Add(delta))) => {
                Some(vec![(String::from("delta"), Value::U32(*delta))])
            }
            _ => None,
        },
    }
}
