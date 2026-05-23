#![forbid(unsafe_code)]
//! Validation helpers for generated LeanRustCore artifacts.

use std::collections::BTreeSet;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GeneratedSummary {
    pub functions: BTreeSet<String>,
    pub types: BTreeSet<String>,
}

pub fn parse_json_artifact(input: &str) -> Result<serde_json::Value, serde_json::Error> {
    serde_json::from_str(input)
}

pub fn summarize_generated_rust(source: &str) -> Result<GeneratedSummary, syn::Error> {
    let file = syn::parse_file(source)?;
    let mut functions = BTreeSet::new();
    let mut types = BTreeSet::new();
    for item in file.items {
        match item {
            syn::Item::Fn(item) => {
                functions.insert(item.sig.ident.to_string());
            }
            syn::Item::Struct(item) => {
                types.insert(item.ident.to_string());
            }
            syn::Item::Enum(item) => {
                types.insert(item.ident.to_string());
            }
            _ => {}
        }
    }
    Ok(GeneratedSummary { functions, types })
}

pub fn target_validation_counts(snapshot: &str) -> Option<(usize, usize)> {
    let mut type_count = None;
    let mut fn_count = None;
    for line in snapshot.lines() {
        if let Some(rest) = line.strip_prefix("TYPE_COUNT\t") {
            type_count = rest.parse::<usize>().ok();
        }
        if let Some(rest) = line.strip_prefix("FN_COUNT\t") {
            fn_count = rest.parse::<usize>().ok();
        }
    }
    match (type_count, fn_count) {
        (Some(t), Some(f)) => Some((t, f)),
        _ => None,
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TargetValue {
    Unit,
    Bool(bool),
    U32(u32),
    ListU32(Vec<u32>),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TargetTerm {
    Unit,
    Bool(bool),
    U32(u32),
    Add(Box<TargetTerm>, Box<TargetTerm>),
    Eq(Box<TargetTerm>, Box<TargetTerm>),
    If(Box<TargetTerm>, Box<TargetTerm>, Box<TargetTerm>),
    ListLength(Box<TargetTerm>),
    List(Vec<TargetTerm>),
}

pub fn eval_target_term(term: &TargetTerm) -> Option<TargetValue> {
    match term {
        TargetTerm::Unit => Some(TargetValue::Unit),
        TargetTerm::Bool(value) => Some(TargetValue::Bool(*value)),
        TargetTerm::U32(value) => Some(TargetValue::U32(*value)),
        TargetTerm::Add(a, b) => match (eval_target_term(a)?, eval_target_term(b)?) {
            (TargetValue::U32(a), TargetValue::U32(b)) => Some(TargetValue::U32(a.wrapping_add(b))),
            _ => None,
        },
        TargetTerm::Eq(a, b) => Some(TargetValue::Bool(
            eval_target_term(a)? == eval_target_term(b)?,
        )),
        TargetTerm::If(cond, when_true, when_false) => match eval_target_term(cond)? {
            TargetValue::Bool(true) => eval_target_term(when_true),
            TargetValue::Bool(false) => eval_target_term(when_false),
            _ => None,
        },
        TargetTerm::ListLength(xs) => match eval_target_term(xs)? {
            TargetValue::ListU32(values) => Some(TargetValue::U32(values.len() as u32)),
            _ => None,
        },
        TargetTerm::List(values) => {
            let mut out = Vec::new();
            for value in values {
                match eval_target_term(value)? {
                    TargetValue::U32(value) => out.push(value),
                    _ => return None,
                }
            }
            Some(TargetValue::ListU32(out))
        }
    }
}

pub fn target_grammar_heads() -> &'static [&'static str] {
    &[
        "literal",
        "variable",
        "let",
        "if",
        "match",
        "loop",
        "call",
        "struct",
        "enum",
        "box",
        "deref",
        "closure",
        "dictionary",
        "effect",
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generated_subset_semantics_interprets_core_terms() {
        let term = TargetTerm::If(
            Box::new(TargetTerm::Eq(
                Box::new(TargetTerm::U32(1)),
                Box::new(TargetTerm::U32(1)),
            )),
            Box::new(TargetTerm::Add(
                Box::new(TargetTerm::U32(40)),
                Box::new(TargetTerm::U32(2)),
            )),
            Box::new(TargetTerm::U32(0)),
        );
        assert_eq!(eval_target_term(&term), Some(TargetValue::U32(42)));
        assert_eq!(
            eval_target_term(&TargetTerm::ListLength(Box::new(TargetTerm::List(vec![
                TargetTerm::U32(1),
                TargetTerm::U32(2),
                TargetTerm::U32(3),
            ])))),
            Some(TargetValue::U32(3))
        );
    }

    #[test]
    fn target_grammar_heads_are_complete() {
        for head in [
            "literal",
            "variable",
            "let",
            "if",
            "match",
            "loop",
            "call",
            "struct",
            "enum",
            "box",
            "deref",
            "closure",
            "dictionary",
            "effect",
        ] {
            assert!(target_grammar_heads().contains(&head));
        }
    }

    #[test]
    fn parses_valid_json_and_rejects_malformed_json() {
        assert!(parse_json_artifact(r#"{"format":"ok"}"#).is_ok());
        assert!(parse_json_artifact(r#"{"format": "broken""#).is_err());
    }

    #[test]
    fn summarizes_generated_rust_items() {
        let summary = summarize_generated_rust(
            "pub struct Point { pub x: u32 } pub enum E { A } pub fn f() {}",
        )
        .unwrap();
        assert!(summary.types.contains("Point"));
        assert!(summary.types.contains("E"));
        assert!(summary.functions.contains("f"));
    }

    #[test]
    fn parses_target_validation_counts() {
        assert_eq!(
            target_validation_counts("TYPE_COUNT\t2\nFN_COUNT\t3\n"),
            Some((2, 3))
        );
    }
}
