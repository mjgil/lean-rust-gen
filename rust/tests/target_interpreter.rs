#![allow(dead_code)]

use std::collections::BTreeMap;

use lean_rust_core_generated::*;
use num_bigint::{BigInt, BigUint};

const TARGET_VALIDATION_SNAPSHOT: &str = include_str!("../target-validation.txt");

#[derive(Clone, Debug, PartialEq, Eq)]
enum Value {
    Bool(bool),
    U32(u32),
    Nat(BigUint),
    Int(BigInt),
    ListU32(Vec<u32>),
    OptionU32(Option<u32>),
    StepStay,
    StepJump(u32),
    TupleU32(u32, u32),
}

type Env = BTreeMap<String, Value>;

#[test]
fn interpreted_target_fingerprints_match_compiled_exact_integer_rust() {
    let mut env = Env::new();
    env.insert("a".into(), Value::Nat(BigUint::from(40u32)));
    env.insert("b".into(), Value::Nat(BigUint::from(2u32)));
    assert_eq!(
        eval_expr(fingerprint_for("exact_nat_add"), &env),
        Value::Nat(BigUint::from(42u32))
    );
    assert_eq!(
        exact_nat_add(BigUint::from(40u32), BigUint::from(2u32)),
        BigUint::from(42u32)
    );

    env.insert("a".into(), Value::Nat(BigUint::from(7u32)));
    env.insert("b".into(), Value::Nat(BigUint::from(6u32)));
    assert_eq!(
        eval_expr(fingerprint_for("exact_nat_mul"), &env),
        Value::Nat(BigUint::from(42u32))
    );
    assert_eq!(
        exact_nat_mul(BigUint::from(7u32), BigUint::from(6u32)),
        BigUint::from(42u32)
    );

    env.insert("a".into(), Value::Int(BigInt::from(-7i32)));
    env.insert("b".into(), Value::Int(BigInt::from(5i32)));
    assert_eq!(
        eval_expr(fingerprint_for("exact_int_add"), &env),
        Value::Int(BigInt::from(-2i32))
    );
    assert_eq!(
        exact_int_add(BigInt::from(-7i32), BigInt::from(5i32)),
        BigInt::from(-2i32)
    );
}

#[test]
fn interpreted_target_fingerprints_cover_captured_closures_and_typeclass_erasure() {
    let mut env = Env::new();
    env.insert("delta".into(), Value::U32(5));
    env.insert("xs".into(), Value::ListU32(vec![1, u32::MAX]));
    assert_eq!(
        eval_expr(fingerprint_for("list_map_add_capture_u32"), &env),
        Value::ListU32(vec![6, 4])
    );
    assert_eq!(list_map_add_capture_u32(5, vec![1, u32::MAX]), vec![6, 4]);

    env.clear();
    env.insert("delta".into(), Value::U32(5));
    env.insert("x".into(), Value::U32(37));
    assert_eq!(
        eval_expr(fingerprint_for("closure_apply_capture_u32"), &env),
        Value::U32(42)
    );
    assert_eq!(closure_apply_capture_u32(5, 37), 42);

    env.clear();
    env.insert("a".into(), Value::U32(7));
    env.insert("b".into(), Value::U32(7));
    assert_eq!(
        eval_expr(fingerprint_for("generic_beq_u32"), &env),
        Value::Bool(true)
    );
    assert!(generic_beq_u32(7, 7));

    env.insert("b".into(), Value::U32(8));
    assert_eq!(
        eval_expr(fingerprint_for("generic_beq_u32"), &env),
        Value::Bool(false)
    );
    assert!(!generic_beq_u32(7, 8));
}

#[test]
fn interpreted_target_fingerprints_cover_standard_combinators_and_dependent_erasure() {
    let mut env = Env::new();
    env.insert("xs".into(), Value::ListU32(vec![0, 1, 0, 2]));
    assert_eq!(
        eval_expr(fingerprint_for("list_filter_nonzero_u32"), &env),
        Value::ListU32(vec![1, 2])
    );
    assert_eq!(list_filter_nonzero_u32(vec![0, 1, 0, 2]), vec![1, 2]);

    env.insert("xs".into(), Value::ListU32(vec![1, 2, u32::MAX]));
    assert_eq!(
        eval_expr(fingerprint_for("list_foldr_sum_u32"), &env),
        Value::U32(2)
    );
    assert_eq!(list_foldr_sum_u32(vec![1, 2, u32::MAX]), 2);

    env.clear();
    env.insert("n".into(), Value::U32(5));
    assert_eq!(
        eval_expr(fingerprint_for("nat_sum_to_u32"), &env),
        Value::U32(10)
    );
    assert_eq!(nat_sum_to_u32(5), 10);

    env.clear();
    env.insert("x".into(), Value::U32(42));
    assert_eq!(
        eval_expr(fingerprint_for("subtype_val_u32"), &env),
        Value::U32(42)
    );
    assert_eq!(subtype_val_u32(42), 42);

    env.clear();
    env.insert("i".into(), Value::U32(7));
    assert_eq!(
        eval_expr(fingerprint_for("fin_val10_u32"), &env),
        Value::U32(7)
    );
    assert_eq!(fin_val10_u32(7), 7);

    env.clear();
    env.insert("xs".into(), Value::ListU32(vec![1, 2, 3]));
    assert_eq!(
        eval_expr(fingerprint_for("vector_echo3_u32"), &env),
        Value::ListU32(vec![1, 2, 3])
    );
    assert_eq!(vector_echo3_u32(vec![1, 2, 3]), vec![1, 2, 3]);
}

#[test]
fn interpreted_target_fingerprints_cover_general_patterns_and_tail_loops() {
    let mut env = Env::new();
    env.insert("flag".into(), Value::Bool(true));
    env.insert("when_true".into(), Value::U32(9));
    env.insert("when_false".into(), Value::U32(20));
    assert_eq!(
        eval_expr(fingerprint_for("general_bool_match_u32"), &env),
        Value::U32(10)
    );
    assert_eq!(general_bool_match_u32(true, 9, 20), 10);

    env.clear();
    env.insert("s".into(), Value::StepJump(u32::MAX));
    env.insert("fallback".into(), Value::U32(7));
    assert_eq!(
        eval_expr(fingerprint_for("general_step_match_u32"), &env),
        Value::U32(0)
    );
    assert_eq!(general_step_match_u32(Step::Jump(u32::MAX), 7), 0);

    env.clear();
    env.insert("a".into(), Value::U32(40));
    env.insert("b".into(), Value::U32(2));
    assert_eq!(
        eval_expr(fingerprint_for("pair_sum_match_u32"), &env),
        Value::U32(42)
    );
    assert_eq!(pair_sum_match_u32(40, 2), 42);

    env.clear();
    env.insert("xs".into(), Value::ListU32(vec![1, 2, 3]));
    assert_eq!(
        eval_expr(fingerprint_for("list_length_u32"), &env),
        Value::U32(3)
    );
    assert_eq!(list_length_u32(vec![1, 2, 3]), 3);

    env.clear();
    env.insert("n".into(), Value::U32(5));
    assert_eq!(
        eval_expr(fingerprint_for("tail_sum_down_u32"), &env),
        Value::U32(15)
    );
    assert_eq!(tail_sum_down_u32(5), 15);
}

fn fingerprint_for(name: &str) -> &'static str {
    for line in TARGET_VALIDATION_SNAPSHOT.lines() {
        let mut parts = line.split('\t');
        if parts.next() == Some("FN") && parts.next() == Some(name) {
            let _args = parts.next();
            let _ret = parts.next();
            return parts.next().expect("function fingerprint field");
        }
    }
    panic!("missing target fingerprint for {name}");
}

fn eval_expr(expr: &str, env: &Env) -> Value {
    let expr = expr.trim();
    if let Some(inner) = call_payload(expr, "var") {
        return env
            .get(inner)
            .unwrap_or_else(|| panic!("missing target-interpreter variable {inner}"))
            .clone();
    }
    if let Some(inner) = call_payload(expr, "lit") {
        return Value::U32(inner.parse().expect("generated numeric literal"));
    }
    if let Some(inner) = call_payload(expr, "bool") {
        return Value::Bool(match inner {
            "true" => true,
            "false" => false,
            other => panic!("unsupported bool literal {other}"),
        });
    }
    if let Some(inner) = call_payload(expr, "add") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 2, "add fingerprint arity");
        return eval_add(eval_expr(args[0], env), eval_expr(args[1], env));
    }
    if let Some(inner) = call_payload(expr, "mul") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 2, "mul fingerprint arity");
        return eval_mul(eval_expr(args[0], env), eval_expr(args[1], env));
    }
    if let Some(inner) = call_payload(expr, "eq") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 2, "eq fingerprint arity");
        return Value::Bool(eval_expr(args[0], env) == eval_expr(args[1], env));
    }
    if let Some(inner) = call_payload(expr, "lt") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 2, "lt fingerprint arity");
        return Value::Bool(match (eval_expr(args[0], env), eval_expr(args[1], env)) {
            (Value::U32(a), Value::U32(b)) => a < b,
            other => panic!("unsupported lt values: {other:?}"),
        });
    }
    if let Some(inner) = call_payload(expr, "gt") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 2, "gt fingerprint arity");
        return Value::Bool(match (eval_expr(args[0], env), eval_expr(args[1], env)) {
            (Value::U32(a), Value::U32(b)) => a > b,
            other => panic!("unsupported gt values: {other:?}"),
        });
    }
    if let Some(inner) = call_payload(expr, "let") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 3, "let fingerprint arity");
        let mut env = env.clone();
        env.insert(args[0].to_string(), eval_expr(args[1], &env));
        return eval_expr(args[2], &env);
    }
    if let Some(inner) = call_payload(expr, "closure_apply") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 3, "closure_apply fingerprint arity");
        let binder = args[0].to_string();
        let value = eval_expr(args[1], env);
        let mut env = env.clone();
        env.insert(binder, value);
        return eval_expr(args[2], &env);
    }
    if let Some(inner) = call_payload(expr, "list_map") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 3, "list_map fingerprint arity");
        let binder = args[0].to_string();
        let values = match eval_expr(args[1], env) {
            Value::ListU32(values) => values,
            other => panic!("list_map target was not a u32 list: {other:?}"),
        };
        let mut out = Vec::new();
        for value in values {
            let mut env = env.clone();
            env.insert(binder.clone(), Value::U32(value));
            match eval_expr(args[2], &env) {
                Value::U32(mapped) => out.push(mapped),
                other => panic!("list_map body did not produce u32: {other:?}"),
            }
        }
        return Value::ListU32(out);
    }
    if let Some(inner) = call_payload(expr, "list_filter") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 3, "list_filter fingerprint arity");
        let binder = args[0].to_string();
        let values = match eval_expr(args[1], env) {
            Value::ListU32(values) => values,
            other => panic!("list_filter target was not a u32 list: {other:?}"),
        };
        let mut out = Vec::new();
        for value in values {
            let mut env = env.clone();
            env.insert(binder.clone(), Value::U32(value));
            match eval_expr(args[2], &env) {
                Value::Bool(true) => out.push(value),
                Value::Bool(false) => {}
                other => panic!("list_filter predicate was not Bool: {other:?}"),
            }
        }
        return Value::ListU32(out);
    }
    if let Some(inner) = call_payload(expr, "list_foldr") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 5, "list_foldr fingerprint arity");
        let elem_binder = args[0].to_string();
        let acc_binder = args[1].to_string();
        let values = match eval_expr(args[2], env) {
            Value::ListU32(values) => values,
            other => panic!("list_foldr target was not a u32 list: {other:?}"),
        };
        let mut acc = eval_expr(args[3], env);
        for value in values.into_iter().rev() {
            let mut env = env.clone();
            env.insert(elem_binder.clone(), Value::U32(value));
            env.insert(acc_binder.clone(), acc);
            acc = eval_expr(args[4], &env);
        }
        return acc;
    }
    if let Some(inner) = call_payload(expr, "list_any") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 3, "list_any fingerprint arity");
        let binder = args[0].to_string();
        let values = match eval_expr(args[1], env) {
            Value::ListU32(values) => values,
            other => panic!("list_any target was not a u32 list: {other:?}"),
        };
        for value in values {
            let mut env = env.clone();
            env.insert(binder.clone(), Value::U32(value));
            if matches!(eval_expr(args[2], &env), Value::Bool(true)) {
                return Value::Bool(true);
            }
        }
        return Value::Bool(false);
    }
    if let Some(inner) = call_payload(expr, "list_all") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 3, "list_all fingerprint arity");
        let binder = args[0].to_string();
        let values = match eval_expr(args[1], env) {
            Value::ListU32(values) => values,
            other => panic!("list_all target was not a u32 list: {other:?}"),
        };
        for value in values {
            let mut env = env.clone();
            env.insert(binder.clone(), Value::U32(value));
            if matches!(eval_expr(args[2], &env), Value::Bool(false)) {
                return Value::Bool(false);
            }
        }
        return Value::Bool(true);
    }
    if let Some(inner) = call_payload(expr, "nat_fold") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 5, "nat_fold fingerprint arity");
        let idx_binder = args[0].to_string();
        let acc_binder = args[1].to_string();
        let mut acc = eval_expr(args[2], env);
        let limit = match eval_expr(args[3], env) {
            Value::U32(n) => n,
            other => panic!("nat_fold limit was not u32: {other:?}"),
        };
        for idx in 0..limit {
            let mut env = env.clone();
            env.insert(idx_binder.clone(), Value::U32(idx));
            env.insert(acc_binder.clone(), acc);
            acc = eval_expr(args[4], &env);
        }
        return acc;
    }

    if let Some(inner) = call_payload(expr, "tuple") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 2, "tuple fingerprint arity");
        return match (eval_expr(args[0], env), eval_expr(args[1], env)) {
            (Value::U32(a), Value::U32(b)) => Value::TupleU32(a, b),
            other => panic!("unsupported tuple values: {other:?}"),
        };
    }
    if let Some(inner) = call_payload(expr, "list_length") {
        return match eval_expr(inner, env) {
            Value::ListU32(values) => Value::U32(values.len() as u32),
            other => panic!("list_length target was not a u32 list: {other:?}"),
        };
    }
    if let Some(inner) = call_payload(expr, "tail_rec_nat") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 5, "tail_rec_nat fingerprint arity");
        let counter_binder = args[0].to_string();
        let acc_binder = args[1].to_string();
        let mut counter = match eval_expr(args[2], env) {
            Value::U32(n) => n,
            other => panic!("tail_rec_nat counter was not u32: {other:?}"),
        };
        let mut acc = eval_expr(args[3], env);
        while counter != 0 {
            let mut env = env.clone();
            env.insert(counter_binder.clone(), Value::U32(counter));
            env.insert(acc_binder.clone(), acc);
            acc = eval_expr(args[4], &env);
            counter = counter.wrapping_sub(1);
        }
        return acc;
    }
    if let Some(inner) = call_payload(expr, "match_pattern") {
        let args = split_top_args(inner);
        assert_eq!(args.len(), 2, "match_pattern fingerprint arity");
        let target = eval_expr(args[0], env);
        for arm in args[1].split('|') {
            let (pattern, body) = arm.split_once("=>").expect("pattern arm separator");
            if let Some(bindings) = match_pattern_bindings(pattern.trim(), &target) {
                let mut env = env.clone();
                for (name, value) in bindings {
                    env.insert(name, value);
                }
                return eval_expr(body.trim(), &env);
            }
        }
        panic!("match_pattern had no matching arm for {target:?}");
    }
    panic!("unsupported target fingerprint expression: {expr}");
}

fn match_pattern_bindings(pattern: &str, value: &Value) -> Option<Vec<(String, Value)>> {
    match (pattern, value) {
        ("true", Value::Bool(true)) | ("false", Value::Bool(false)) => Some(Vec::new()),
        ("Step::Stay()", Value::StepStay) => Some(Vec::new()),
        _ => {
            if let Some(name) = call_payload(pattern, "varpat") {
                return Some(vec![(name.to_string(), value.clone())]);
            }
            if let (Some(inner), Value::StepJump(amount)) =
                (call_payload(pattern, "Step::Jump"), value)
            {
                let name = call_payload(inner, "varpat")?;
                return Some(vec![(name.to_string(), Value::U32(*amount))]);
            }
            if let (Some(inner), Value::OptionU32(Some(amount))) =
                (call_payload(pattern, "Some"), value)
            {
                let name = call_payload(inner, "varpat")?;
                return Some(vec![(name.to_string(), Value::U32(*amount))]);
            }
            if pattern == "None" && matches!(value, Value::OptionU32(None)) {
                return Some(Vec::new());
            }
            if pattern.starts_with('(') && pattern.ends_with(')') {
                if let Value::TupleU32(a, b) = value {
                    let inner = &pattern[1..pattern.len() - 1];
                    let parts = split_top_args(inner);
                    if parts.len() == 2 {
                        let a_name = call_payload(parts[0], "varpat")?;
                        let b_name = call_payload(parts[1], "varpat")?;
                        return Some(vec![
                            (a_name.to_string(), Value::U32(*a)),
                            (b_name.to_string(), Value::U32(*b)),
                        ]);
                    }
                }
            }
            None
        }
    }
}

fn eval_add(a: Value, b: Value) -> Value {
    match (a, b) {
        (Value::U32(a), Value::U32(b)) => Value::U32(a.wrapping_add(b)),
        (Value::Nat(a), Value::Nat(b)) => Value::Nat(a + b),
        (Value::Int(a), Value::Int(b)) => Value::Int(a + b),
        other => panic!("unsupported add values: {other:?}"),
    }
}

fn eval_mul(a: Value, b: Value) -> Value {
    match (a, b) {
        (Value::U32(a), Value::U32(b)) => Value::U32(a.wrapping_mul(b)),
        (Value::Nat(a), Value::Nat(b)) => Value::Nat(a * b),
        (Value::Int(a), Value::Int(b)) => Value::Int(a * b),
        other => panic!("unsupported mul values: {other:?}"),
    }
}

fn call_payload<'a>(expr: &'a str, name: &str) -> Option<&'a str> {
    let prefix = format!("{name}(");
    expr.strip_prefix(&prefix)?.strip_suffix(')')
}

fn split_top_args(input: &str) -> Vec<&str> {
    let mut args = Vec::new();
    let mut depth = 0i32;
    let mut start = 0usize;
    for (idx, ch) in input.char_indices() {
        match ch {
            '(' => depth += 1,
            ')' => depth -= 1,
            ',' if depth == 0 => {
                args.push(input[start..idx].trim());
                start = idx + 1;
            }
            _ => {}
        }
    }
    if start <= input.len() {
        args.push(input[start..].trim());
    }
    args
}
