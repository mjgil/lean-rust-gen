#[path = "target_interpreter/dispatch.rs"]
mod dispatch;
#[path = "target_interpreter/eval.rs"]
mod eval;
#[path = "target_interpreter/model.rs"]
mod model;

use dispatch::dispatch_compiled_function;
use eval::eval_target_function;
use lean_rust_core_validate::TargetValidationFunction;
use model::{function_map, parse_snapshot_functions, sample_args_for};

fn snapshot_function<'a>(
    functions: &'a std::collections::BTreeMap<String, TargetValidationFunction>,
    name: &str,
) -> &'a TargetValidationFunction {
    functions
        .get(name)
        .unwrap_or_else(|| panic!("missing target-validation function {name}"))
}

#[test]
fn generated_subset_semantics_spot_checks_match_compiled_rust() {
    let functions = parse_snapshot_functions();
    let functions = function_map(&functions);

    for name in [
        "exact_nat_add",
        "closure_apply_capture_u32",
        "generic_beq_u32",
        "list_filter_nonzero_u32",
    ] {
        let function = snapshot_function(&functions, name);
        let args = sample_args_for(function).expect("spot-check args should exist");
        let interpreted = eval_target_function(&functions, function, &args)
            .unwrap_or_else(|err| panic!("interpreter failed for {name}: {err}"));
        let compiled = dispatch_compiled_function(name, &args)
            .unwrap_or_else(|err| panic!("dispatch failed for {name}: {err}"));
        assert_eq!(interpreted, compiled, "spot-check mismatch for {name}");
    }
}

#[test]
fn generated_subset_semantics_are_executable_for_every_emitted_function() {
    let functions = parse_snapshot_functions();
    assert_eq!(
        functions.len(),
        126,
        "unexpected target-validation function count"
    );
    let functions_by_name = function_map(&functions);

    for function in &functions {
        let args = sample_args_for(function).unwrap_or_else(|err| {
            panic!("sample-arg generation failed for {}: {err}", function.name)
        });
        let interpreted = eval_target_function(&functions_by_name, function, &args)
            .unwrap_or_else(|err| panic!("interpreter failed for {}: {err}", function.name));
        let compiled = dispatch_compiled_function(&function.name, &args)
            .unwrap_or_else(|err| panic!("compiled dispatch failed for {}: {err}", function.name));
        assert_eq!(
            interpreted, compiled,
            "interpreted result diverged from compiled Rust for {} with fingerprint {}",
            function.name, function.fingerprint
        );
    }
}
