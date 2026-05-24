use lean_rust_core_generated::*;

use super::model::Value;
use super::parse::{call_payload, split_top_args};

pub fn match_pattern_bindings(pattern: &str, value: &Value) -> Option<Vec<(String, Value)>> {
    match (pattern, value) {
        ("true", Value::Bool(true)) | ("false", Value::Bool(false)) => Some(Vec::new()),
        ("None", Value::OptionU32(None))
        | ("None", Value::OptionU64(None))
        | ("None", Value::OptionStep(None)) => Some(Vec::new()),
        ("Choice::First()", Value::Choice(Choice::First))
        | ("Choice::Second()", Value::Choice(Choice::Second))
        | ("Step::Stay()", Value::Step(Step::Stay))
        | ("TaggedU32::Missing()", Value::TaggedU32(TaggedU32::Missing)) => Some(Vec::new()),
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
                match value {
                    Value::ProdU32((left, right)) => {
                        let mut bindings = Vec::new();
                        if let Some(left_name) = call_payload(parts[0], "varpat") {
                            bindings.push((left_name.to_string(), Value::U32(*left)));
                        } else if parts[0] != "_" {
                            return None;
                        }
                        if let Some(right_name) = call_payload(parts[1], "varpat") {
                            bindings.push((right_name.to_string(), Value::U32(*right)));
                        } else if parts[1] != "_" {
                            return None;
                        }
                        return Some(bindings);
                    }
                    Value::ProdUnitU32(right) => {
                        let mut bindings = Vec::new();
                        if let Some(left_name) = call_payload(parts[0], "varpat") {
                            bindings.push((left_name.to_string(), Value::Unit));
                        } else if parts[0] != "_" {
                            return None;
                        }
                        let right_name = call_payload(parts[1], "varpat")?;
                        bindings.push((right_name.to_string(), Value::U32(*right)));
                        return Some(bindings);
                    }
                    _ => {}
                }
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
                Value::ResultU32U32(Err(err)) => Some(vec![(
                    call_payload(pattern, "Err")?.to_string(),
                    Value::U32(*err),
                )]),
                Value::ResultU32OptionU32(Err(err)) => Some(vec![(
                    call_payload(pattern, "Err")?.to_string(),
                    Value::OptionU32(*err),
                )]),
                _ => None,
            },
            _ if pattern.starts_with("Ok(") && pattern.ends_with(')') => match value {
                Value::ResultU32U32(Ok(value)) => Some(vec![(
                    call_payload(pattern, "Ok")?.to_string(),
                    Value::U32(*value),
                )]),
                Value::ResultOptionU32U32(Ok(value)) => Some(vec![(
                    call_payload(pattern, "Ok")?.to_string(),
                    Value::OptionU32(*value),
                )]),
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
