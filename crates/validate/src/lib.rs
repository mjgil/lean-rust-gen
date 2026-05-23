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

#[cfg(test)]
mod tests {
    use super::*;

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
