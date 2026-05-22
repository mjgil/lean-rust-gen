use std::collections::BTreeSet;

use serde_json::Value;
use syn::Item;

const GENERATED_SOURCE: &str = include_str!("../src/generated.rs");
const VALIDATION_REPORT: &str = include_str!("../validation-report.json");
const COMPATIBILITY_REPORT: &str = include_str!("../compatibility-report.json");
const PROOF_REPORT: &str = include_str!("../proof-report.json");
const BUILD_METADATA: &str = include_str!("../build-metadata.json");

fn parse_json_artifact(name: &str, source: &str) -> Value {
    serde_json::from_str(source).unwrap_or_else(|err| panic!("{name} should be valid JSON: {err}"))
}

fn generated_symbols() -> (BTreeSet<String>, BTreeSet<String>) {
    let file = syn::parse_file(GENERATED_SOURCE).expect("generated Rust should parse");
    let mut functions = BTreeSet::new();
    let mut types = BTreeSet::new();

    for item in file.items {
        match item {
            Item::Fn(item) => {
                functions.insert(item.sig.ident.to_string());
            }
            Item::Struct(item) => {
                types.insert(item.ident.to_string());
            }
            Item::Enum(item) => {
                types.insert(item.ident.to_string());
            }
            _ => {}
        }
    }

    (functions, types)
}

#[test]
fn generated_json_artifacts_are_valid_json() {
    for (name, source) in [
        ("validation-report.json", VALIDATION_REPORT),
        ("compatibility-report.json", COMPATIBILITY_REPORT),
        ("proof-report.json", PROOF_REPORT),
        ("build-metadata.json", BUILD_METADATA),
    ] {
        parse_json_artifact(name, source);
    }
}

#[test]
fn compatibility_report_records_feature_tags() {
    let report = parse_json_artifact("compatibility-report.json", COMPATIBILITY_REPORT);
    assert_eq!(
        report["feature_tag_schema"].as_str(),
        Some("lean-rust-core.feature-tags.v1")
    );

    let diagnostics = report["diagnostics"]
        .as_array()
        .expect("diagnostics should be an array");
    assert!(diagnostics.iter().any(|diagnostic| {
        diagnostic["features"]
            .as_array()
            .is_some_and(|features| features.iter().any(|tag| tag == "structural-list-loop"))
    }));
    assert!(diagnostics.iter().any(|diagnostic| {
        diagnostic["features"]
            .as_array()
            .is_some_and(|features| features.iter().any(|tag| tag == "exact-integer-mode"))
    }));
    assert!(diagnostics
        .iter()
        .all(|diagnostic| diagnostic.get("next_feature").is_some()));
}

#[test]
fn validation_report_counts_match_generated_rust() {
    let (functions, types) = generated_symbols();
    let report = parse_json_artifact("validation-report.json", VALIDATION_REPORT);

    assert_eq!(
        report["generated_function_count"].as_u64(),
        Some(functions.len() as u64)
    );
    assert_eq!(
        report["generated_type_count"].as_u64(),
        Some(types.len() as u64)
    );

    let required_functions = report["required_functions"]
        .as_array()
        .expect("required_functions array");
    assert_eq!(required_functions.len(), functions.len());
    for name in required_functions {
        let name = name.as_str().expect("function name string");
        assert!(
            functions.contains(name),
            "required function {name} was not generated"
        );
    }

    let required_types = report["required_types"]
        .as_array()
        .expect("required_types array");
    assert_eq!(required_types.len(), types.len());
    for name in required_types {
        let name = name.as_str().expect("type name string");
        assert!(
            types.contains(name),
            "required type {name} was not generated"
        );
    }
}

#[test]
fn compatibility_report_diagnostics_match_generated_output() {
    let (functions, _) = generated_symbols();
    let report = parse_json_artifact("compatibility-report.json", COMPATIBILITY_REPORT);

    assert_eq!(
        report["generated_function_count"].as_u64(),
        Some(functions.len() as u64)
    );

    let diagnostics = report["diagnostics"]
        .as_array()
        .expect("diagnostics should be an array");
    let mut supported_functions = BTreeSet::new();

    for diagnostic in diagnostics {
        let rust_name = diagnostic["rust_name"].as_str().expect("rust_name string");
        let code = diagnostic["code"].as_str().expect("code string");
        let features = diagnostic["features"]
            .as_array()
            .expect("diagnostic features should be an array");
        assert!(
            !features.is_empty() || code == "unsupported-declaration",
            "supported diagnostic {rust_name} should carry at least one feature tag"
        );
        assert!(
            diagnostic.get("next_feature").is_some(),
            "diagnostic {rust_name} should include a next_feature field"
        );

        match code {
            "supported" => {
                assert!(
                    functions.contains(rust_name),
                    "supported diagnostic {rust_name} should be generated"
                );
                supported_functions.insert(rust_name.to_string());
            }
            "unsupported-declaration" => {
                assert!(
                    !functions.contains(rust_name),
                    "unsupported diagnostic {rust_name} must not be generated"
                );
            }
            other => panic!("unexpected compatibility diagnostic code: {other}"),
        }
    }

    for function in functions {
        assert!(
            supported_functions.contains(&function),
            "generated function {function} lacks a supported diagnostic"
        );
    }
}

#[test]
fn validation_report_records_current_subset_gates() {
    let report = include_str!("../validation-report.json");

    assert!(report.contains("lean-rust-core.rust-validation.v1"));
    assert!(report.contains("direct-lean-emits-rust"));
    assert!(report.contains("lean-evaluator-differential-tests"));
    assert!(report.contains("safe-rust-subset-gate"));
    assert!(report.contains("payload-enum-match-lowering"));
    assert!(report.contains("general-pattern-compiler"));
    assert!(report.contains("constructor-pattern-rust-emission"));
    assert!(report.contains("first-order-call-lowering"));
    assert!(report.contains("surface-evaluator-extracted-subset-tests"));
    assert!(report.contains("extractor-owned-surface-artifact"));
    assert!(report.contains("rust-identifier-hygiene"));
    assert!(report.contains("syn-parser-backed-validation"));
    assert!(report.contains("json-artifact-parse-validation"));
    assert!(report.contains("compatibility-report-output-consistency"));
    assert!(report.contains("exact-toolchain-pins"));
    assert!(report.contains("release-fallback-ban"));
    assert!(report.contains("automatic-monomorphization"));
    assert!(report.contains("phase-1-recursion-policy"));
    assert!(report.contains("parameterized-data-lowering"));
    assert!(report.contains("standard-container-shapes"));
    assert!(report.contains("standard-combinator-lowering"));
    assert!(report.contains("structural-recursion-lowering"));
    assert!(report.contains("std-library-lowering-table"));
    assert!(report.contains("pure-monadic-do-lowering"));
    assert!(report.contains("tail-recursion-loop-lowering"));
    assert!(report.contains("list-length-structural-lowering"));
    assert!(report.contains("dependent-shape-erasure"));
    assert!(report.contains("proof-field-erasure"));
    assert!(report.contains("exact-integer-modes"));
    assert!(report.contains("captured-closure-conversion"));
    assert!(report.contains("typeclass-dictionary-erasure"));
    assert!(report.contains("transitive-helper-extraction"));
    assert!(report.contains("proof-erased-binders"));
    assert!(report.contains("limited-higher-order-function-pointer"));
    assert!(report.contains("rust-to-target-ir-translation-validation"));
    assert!(report.contains("target-validation-snapshot"));
    assert!(report.contains("target-fingerprint-interpreter"));
    assert!(report.contains("property-differential-seeds"));
    assert!(report.contains("ffi-boundary-exporter"));
    assert!(report.contains("ffi-feature-isolation"));
    assert!(report.contains("ffi-result-status-out-params"));
    assert!(report.contains("lean-rust-core.target-validation.v2"));
    assert!(report.contains("leanprover/lean4:v4.22.0"));
    assert!(report.contains("1.85.0"));
    assert!(!report.contains("\"status\": \"failed\""));
}

#[test]
fn generated_source_stays_inside_safe_subset_textually() {
    let source = include_str!("../src/generated.rs");

    for banned in [
        "unsafe",
        "extern \"C\"",
        "panic!",
        "todo!",
        "unimplemented!",
        "/* malformed",
        "unsupported wrapping op",
    ] {
        assert!(
            !source.contains(banned),
            "generated Rust contained banned fragment: {banned}"
        );
    }

    for required in [
        "pub struct Point",
        "pub struct BoundedProof",
        "pub struct BoxedU32",
        "pub enum Choice",
        "pub enum TaggedU32",
        "pub enum Step",
        "pub enum Ordering",
        "pub fn clamp_u32",
        "pub fn echo_string",
        "pub fn echo_list_u32",
        "pub fn echo_array_u32",
        "pub fn list_map_inc_u32",
        "pub fn list_fold_sum_u32",
        "pub fn list_filter_nonzero_u32",
        "pub fn list_foldr_sum_u32",
        "pub fn exact_nat_add",
        "pub fn exact_int_add",
        "pub fn exact_int_mul",
        "pub fn list_append_u32",
        "pub fn list_find_nonzero_u32",
        "pub fn array_push_u32",
        "pub fn option_getd_u32",
        "pub fn result_map_err_inc_u32",
        "pub fn except_do_inc_u32",
        "pub fn reader_add_env_u32",
        "pub fn state_tick_u32",
        "pub fn echo_prod_u32",
        "pub fn echo_sum_u32",
        "pub fn helper_chain_u32",
        "pub fn proof_erased_u32",
        "pub fn bounded_proof_make_u32",
        "pub fn bounded_proof_value_u32",
        "pub fn subtype_val_u32",
        "pub fn subtype_inc_u32",
        "pub fn subtype_roundtrip_u32",
        "pub fn fin_checked10_u32",
        "pub fn vector_map_inc3_u32",
        "pub fn boxed_u32",
        "pub fn tagged_default_u32",
        "pub fn unsupported_higher_order_u32",
        "pub fn option_default_u64",
        "pub fn generic_beq_u32",
        "pub fn step_amount_or",
        "pub fn inc_twice_u32",
        "pub fn step_amount_plus_one_or",
        "pub fn generic_identity__u32",
        "pub fn generic_choose__point",
        "pub fn generic_option_default__step",
        "pub fn helper_inc_fixed",
        "pub fn nat_sum_to_u32",
        "pub fn vector_echo3_u32",
        "pub fn general_bool_match_u32",
        "pub fn general_option_match_u32",
        "pub fn general_step_match_u32",
        "pub fn pair_sum_match_u32",
        "pub fn list_length_u32",
        "pub fn tail_sum_down_u32",
        "pub fn option_do_inc_u32",
        "pub fn closure_apply_capture_u32",
        "pub fn auto_identity_u32",
        "pub fn auto_choose_point",
        "pub fn auto_option_default_step",
    ] {
        assert!(
            source.contains(required),
            "generated Rust did not contain required fragment: {required}"
        );
    }
}

#[test]
fn build_metadata_records_pins_and_fallback_policy() {
    let metadata = include_str!("../build-metadata.json");

    assert!(metadata.contains("lean-rust-core.build-metadata.v1"));
    assert!(metadata.contains("leanprover/lean4:v4.22.0"));
    assert!(metadata.contains("1.85.0"));
    assert!(metadata.contains("LEAN_RUST_CORE_ALLOW_FALLBACK"));
    assert!(metadata.contains("rust/target-validation.txt"));
    assert!(metadata.contains("rust/src/ffi_generated.rs"));
}

#[test]
fn target_validation_snapshot_records_generated_subset() {
    let snapshot = include_str!("../target-validation.txt");

    assert!(snapshot.contains("FORMAT\tlean-rust-core.target-validation.v2"));
    assert!(snapshot.contains("TYPE\tstruct\tBoundedProof"));
    assert!(snapshot.contains("TYPE\tstruct\tBoxedU32"));
    assert!(snapshot.contains("TYPE\tenum\tOrdering"));
    assert!(snapshot.contains("FN\tclamp_u32"));
    assert!(snapshot.contains("FN\tunsupported_higher_order_u32"));
    assert!(snapshot.contains("call_value(var(f),var(x))"));
    assert!(snapshot.contains("FN\tlist_map_inc_u32"));
    assert!(snapshot.contains("list_map(x,var(xs),add(var(x),lit(1)))"));
    assert!(snapshot.contains("FN\tlist_fold_sum_u32"));
    assert!(snapshot.contains("list_foldl(acc,x,lit(0),var(xs),add(var(acc),var(x)))"));
    assert!(snapshot.contains("FN\tlist_filter_nonzero_u32"));
    assert!(snapshot.contains("FN\tnat_sum_to_u32"));
    assert!(snapshot.contains("FN\tvector_echo3_u32"));
    assert!(snapshot.contains("FN\tgeneral_bool_match_u32"));
    assert!(snapshot.contains("FN\tlist_length_u32"));
    assert!(snapshot.contains("FN\ttail_sum_down_u32"));
    assert!(snapshot.contains("FN\texact_nat_add"));
    assert!(snapshot.contains("num_bigint::BigUint"));
    assert!(snapshot.contains("FN\tgeneric_beq_u32"));
    assert!(snapshot.contains("FN\tdecidable_eq_u32"));
    assert!(snapshot.contains("FN\tord_compare_u32"));
    assert!(snapshot.contains("if(lt(var(a),var(b)),enum(Ordering::Lt),if(eq(var(a),var(b)),enum(Ordering::Eq),enum(Ordering::Gt)))"));
    assert!(snapshot.contains("FN\toption_do_inc_u32"));
    assert!(snapshot.contains("match_option(var(x),none=>none|some(v)=>some(add(var(v),lit(1))))"));
    assert!(snapshot.contains("FN\tclosure_apply_capture_u32"));
    assert!(snapshot.contains("let(y,var(x),add(var(y),var(delta)))"));
    assert!(snapshot.contains("FN\tbounded_proof_make_u32"));
    assert!(snapshot.contains("FN\tsubtype_val_u32"));
    assert!(snapshot.contains("FN\tsubtype_inc_u32"));
    assert!(snapshot.contains("FN\tsubtype_roundtrip_u32"));
    assert!(snapshot.contains("FN\tfin_checked10_u32"));
    assert!(snapshot.contains("FN\tvector_map_inc3_u32"));
    assert!(snapshot.contains("FN\tlist_append_u32"));
    assert!(snapshot.contains("FN\treader_add_env_u32"));
    assert!(snapshot.contains("FN\tstate_tick_u32"));
}

#[test]
fn ffi_boundary_snapshot_is_feature_gated_and_separate() {
    let ffi = include_str!("../src/ffi_generated.rs");
    let lib = include_str!("../src/lib.rs");

    assert!(lib.contains("#[cfg(feature = \"ffi\")]"));
    assert!(ffi.contains("extern \"C\" fn lrc_add_u32"));
    assert!(ffi.contains("unsafe extern \"C\" fn lrc_result_ok_u32"));
    assert!(ffi.contains("lower_result_u32_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_general_bool_match_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_pair_sum_match_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_tail_sum_down_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_reader_add_env_u32"));
    assert!(ffi.contains("unsafe extern \"C\" fn lrc_except_do_inc_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_subtype_inc_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_subtype_roundtrip_u32"));
}
