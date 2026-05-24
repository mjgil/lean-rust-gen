use lean_rust_core_generated::*;
use lean_rust_core_validate::TargetValidationFunction;

use super::matchers::{match_enum_bindings, match_pattern_bindings};
use super::model::{
    as_binary_tree_u32, as_bool, as_even_node, as_expr_u32, as_odd_node, as_option_u32, as_string,
    as_u32, as_vec_rosetree_u32, as_vec_u32, Env, FunctionMap, UnaryFnU32, Value,
};
use super::parse::{call_payload, split_top_args, split_top_level};
use super::runtime_calls::eval_runtime_call;

pub fn eval_target_function(
    functions: &FunctionMap,
    function: &TargetValidationFunction,
    args: &[Value],
) -> Result<Value, String> {
    if function.args.len() != args.len() {
        return Err(format!(
            "target-interpreter arg length mismatch for {}: expected {}, got {}",
            function.name,
            function.args.len(),
            args.len()
        ));
    }

    let env = function
        .args
        .iter()
        .zip(args.iter())
        .map(|(arg, value)| (arg.name.clone(), value.clone()))
        .collect::<Env>();
    eval_expr(functions, &function.fingerprint, &env)
}

fn eval_expr(functions: &FunctionMap, expr: &str, env: &Env) -> Result<Value, String> {
    let expr = expr.trim();
    if let Some(inner) = call_payload(expr, "var") {
        return env
            .get(inner)
            .cloned()
            .ok_or_else(|| format!("missing target-interpreter variable {inner}"));
    }
    if let Some(inner) = call_payload(expr, "lit") {
        return Ok(Value::U32(
            inner
                .parse()
                .map_err(|_| format!("bad u32 literal {inner}"))?,
        ));
    }
    if let Some(inner) = call_payload(expr, "bool") {
        return Ok(Value::Bool(match inner {
            "true" => true,
            "false" => false,
            other => return Err(format!("unsupported bool literal {other}")),
        }));
    }
    if expr == "none" {
        return Ok(Value::OptionU32(None));
    }
    if expr == "unit" {
        return Ok(Value::Unit);
    }
    if let Some(inner) = call_payload(expr, "some") {
        let value = eval_expr(functions, inner, env)?;
        return match value {
            Value::OptionU32(nested) => Ok(Value::NestedOptionU32(Some(nested))),
            Value::U32(value) => Ok(Value::OptionU32(Some(value))),
            Value::U64(value) => Ok(Value::OptionU64(Some(value))),
            Value::Step(step) => Ok(Value::OptionStep(Some(step))),
            other => Err(format!("unsupported some(...) payload {other:?}")),
        };
    }
    if let Some(inner) = call_payload(expr, "ok") {
        let value = eval_expr(functions, inner, env)?;
        return match value {
            Value::Unit => Ok(Value::ResultUnitU32(Ok(()))),
            Value::U32(value) => Ok(Value::ResultU32U32(Ok(value))),
            Value::OptionU32(value) => Ok(Value::ResultOptionU32U32(Ok(value))),
            other => Err(format!("unsupported ok(...) payload {other:?}")),
        };
    }
    if let Some(inner) = call_payload(expr, "err") {
        let value = eval_expr(functions, inner, env)?;
        return match value {
            Value::U32(value) => Ok(Value::ResultU32U32(Err(value))),
            Value::String(value) => Ok(Value::ResultU32String(Err(value))),
            Value::OptionU32(value) => Ok(Value::ResultU32OptionU32(Err(value))),
            other => Err(format!("unsupported err(...) payload {other:?}")),
        };
    }
    if let Some(inner) = call_payload(expr, "add") {
        let args = split_top_args(inner);
        return eval_add(
            eval_expr(functions, args[0], env)?,
            eval_expr(functions, args[1], env)?,
        );
    }
    if let Some(inner) = call_payload(expr, "sub") {
        let args = split_top_args(inner);
        return eval_sub(
            eval_expr(functions, args[0], env)?,
            eval_expr(functions, args[1], env)?,
        );
    }
    if let Some(inner) = call_payload(expr, "mul") {
        let args = split_top_args(inner);
        return eval_mul(
            eval_expr(functions, args[0], env)?,
            eval_expr(functions, args[1], env)?,
        );
    }
    if let Some(inner) = call_payload(expr, "eq") {
        let args = split_top_args(inner);
        return Ok(Value::Bool(
            eval_expr(functions, args[0], env)? == eval_expr(functions, args[1], env)?,
        ));
    }
    if let Some(inner) = call_payload(expr, "lt") {
        let args = split_top_args(inner);
        return Ok(Value::Bool(
            as_u32(&eval_expr(functions, args[0], env)?)?
                < as_u32(&eval_expr(functions, args[1], env)?)?,
        ));
    }
    if let Some(inner) = call_payload(expr, "gt") {
        let args = split_top_args(inner);
        return Ok(Value::Bool(
            as_u32(&eval_expr(functions, args[0], env)?)?
                > as_u32(&eval_expr(functions, args[1], env)?)?,
        ));
    }
    if let Some(inner) = call_payload(expr, "if") {
        let args = split_top_args(inner);
        return if as_bool(&eval_expr(functions, args[0], env)?)? {
            eval_expr(functions, args[1], env)
        } else {
            eval_expr(functions, args[2], env)
        };
    }
    if let Some(inner) = call_payload(expr, "let") {
        let args = split_top_args(inner);
        let mut nested = env.clone();
        let value = eval_expr(functions, args[1], env)?;
        nested.insert(args[0].to_string(), value);
        return eval_expr(functions, args[2], &nested);
    }
    if let Some(inner) = call_payload(expr, "field") {
        let args = split_top_args(inner);
        return eval_field(eval_expr(functions, args[0], env)?, args[1]);
    }
    if let Some(inner) = call_payload(expr, "struct") {
        return eval_struct(functions, inner, env);
    }
    if let Some(inner) = call_payload(expr, "enum") {
        return eval_enum(functions, inner, env);
    }
    if let Some(inner) = call_payload(expr, "box") {
        return Ok(Value::Boxed(Box::new(eval_expr(functions, inner, env)?)));
    }
    if let Some(inner) = call_payload(expr, "deref") {
        return match eval_expr(functions, inner, env)? {
            Value::Boxed(value) => Ok(*value),
            other => Err(format!("cannot deref non-boxed value {other:?}")),
        };
    }
    if let Some(inner) = call_payload(expr, "call") {
        let args = split_top_args(inner);
        let values = args[1..]
            .iter()
            .map(|arg| eval_expr(functions, arg, env))
            .collect::<Result<Vec<_>, _>>()?;
        if let Some(result) = eval_runtime_call(args[0], &values) {
            return result;
        }
        let function = functions
            .get(args[0])
            .ok_or_else(|| format!("missing callee {}", args[0]))?;
        return eval_target_function(functions, function, &values);
    }
    if let Some(inner) = call_payload(expr, "call_value") {
        let args = split_top_args(inner);
        return match (
            eval_expr(functions, args[0], env)?,
            eval_expr(functions, args[1], env)?,
        ) {
            (Value::UnaryFnU32(UnaryFnU32::Inc), Value::U32(value)) => {
                Ok(Value::U32(inc_u32(value)))
            }
            other => Err(format!("unsupported call_value {other:?}")),
        };
    }
    if let Some(inner) = call_payload(expr, "closure_apply") {
        let args = split_top_args(inner);
        let mut nested = env.clone();
        nested.insert(args[0].to_string(), eval_expr(functions, args[1], env)?);
        return eval_expr(functions, args[2], &nested);
    }
    if let Some(inner) = call_payload(expr, "compare") {
        let args = split_top_args(inner);
        let lhs = as_u32(&eval_expr(functions, args[0], env)?)?;
        let rhs = as_u32(&eval_expr(functions, args[1], env)?)?;
        return Ok(Value::Ordering(match lhs.cmp(&rhs) {
            std::cmp::Ordering::Less => Ordering::Lt,
            std::cmp::Ordering::Equal => Ordering::Eq,
            std::cmp::Ordering::Greater => Ordering::Gt,
        }));
    }
    if let Some(inner) = call_payload(expr, "default") {
        return match inner {
            "u32" => Ok(Value::U32(0)),
            other => Err(format!("unsupported default type {other}")),
        };
    }
    if let Some(inner) = call_payload(expr, "to_string") {
        let args = split_top_args(inner);
        return Ok(Value::String(
            as_u32(&eval_expr(functions, args[1], env)?)?.to_string(),
        ));
    }
    if let Some(inner) = call_payload(expr, "repr") {
        let args = split_top_args(inner);
        return Ok(Value::String(format!(
            "{:?}",
            as_u32(&eval_expr(functions, args[1], env)?)?
        )));
    }
    if let Some(inner) = call_payload(expr, "list_append") {
        let args = split_top_args(inner);
        let mut left = as_vec_u32(&eval_expr(functions, args[0], env)?)?;
        left.extend(as_vec_u32(&eval_expr(functions, args[1], env)?)?);
        return Ok(Value::VecU32(left));
    }
    if let Some(inner) = call_payload(expr, "array_push") {
        let args = split_top_args(inner);
        let mut values = as_vec_u32(&eval_expr(functions, args[0], env)?)?;
        values.push(as_u32(&eval_expr(functions, args[1], env)?)?);
        return Ok(Value::VecU32(values));
    }
    if let Some(inner) = call_payload(expr, "list_map") {
        let args = split_top_args(inner);
        let binder = args[0].to_string();
        let values = as_vec_u32(&eval_expr(functions, args[1], env)?)?;
        let mut out = Vec::new();
        for value in values {
            let mut nested = env.clone();
            nested.insert(binder.clone(), Value::U32(value));
            out.push(as_u32(&eval_expr(functions, args[2], &nested)?)?);
        }
        return Ok(Value::VecU32(out));
    }
    if let Some(inner) = call_payload(expr, "list_filter") {
        let args = split_top_args(inner);
        let binder = args[0].to_string();
        let values = as_vec_u32(&eval_expr(functions, args[1], env)?)?;
        let mut out = Vec::new();
        for value in values {
            let mut nested = env.clone();
            nested.insert(binder.clone(), Value::U32(value));
            if as_bool(&eval_expr(functions, args[2], &nested)?)? {
                out.push(value);
            }
        }
        return Ok(Value::VecU32(out));
    }
    if let Some(inner) = call_payload(expr, "list_foldl") {
        let args = split_top_args(inner);
        let acc_name = args[0].to_string();
        let elem_name = args[1].to_string();
        let mut acc = eval_expr(functions, args[2], env)?;
        for value in as_vec_u32(&eval_expr(functions, args[3], env)?)? {
            let mut nested = env.clone();
            nested.insert(acc_name.clone(), acc);
            nested.insert(elem_name.clone(), Value::U32(value));
            acc = eval_expr(functions, args[4], &nested)?;
        }
        return Ok(acc);
    }
    if let Some(inner) = call_payload(expr, "list_foldr") {
        let args = split_top_args(inner);
        let elem_name = args[0].to_string();
        let acc_name = args[1].to_string();
        let mut acc = eval_expr(functions, args[3], env)?;
        for value in as_vec_u32(&eval_expr(functions, args[2], env)?)?
            .into_iter()
            .rev()
        {
            let mut nested = env.clone();
            nested.insert(elem_name.clone(), Value::U32(value));
            nested.insert(acc_name.clone(), acc);
            acc = eval_expr(functions, args[4], &nested)?;
        }
        return Ok(acc);
    }
    if let Some(inner) = call_payload(expr, "list_any") {
        let args = split_top_args(inner);
        let binder = args[0].to_string();
        for value in as_vec_u32(&eval_expr(functions, args[1], env)?)? {
            let mut nested = env.clone();
            nested.insert(binder.clone(), Value::U32(value));
            if as_bool(&eval_expr(functions, args[2], &nested)?)? {
                return Ok(Value::Bool(true));
            }
        }
        return Ok(Value::Bool(false));
    }
    if let Some(inner) = call_payload(expr, "list_all") {
        let args = split_top_args(inner);
        let binder = args[0].to_string();
        for value in as_vec_u32(&eval_expr(functions, args[1], env)?)? {
            let mut nested = env.clone();
            nested.insert(binder.clone(), Value::U32(value));
            if !as_bool(&eval_expr(functions, args[2], &nested)?)? {
                return Ok(Value::Bool(false));
            }
        }
        return Ok(Value::Bool(true));
    }
    if let Some(inner) = call_payload(expr, "list_find") {
        let args = split_top_args(inner);
        let binder = args[0].to_string();
        for value in as_vec_u32(&eval_expr(functions, args[1], env)?)? {
            let mut nested = env.clone();
            nested.insert(binder.clone(), Value::U32(value));
            if as_bool(&eval_expr(functions, args[2], &nested)?)? {
                return Ok(Value::OptionU32(Some(value)));
            }
        }
        return Ok(Value::OptionU32(None));
    }
    if let Some(inner) = call_payload(expr, "nat_fold") {
        let args = split_top_args(inner);
        let idx_name = args[0].to_string();
        let acc_name = args[1].to_string();
        let mut acc = eval_expr(functions, args[2], env)?;
        for idx in 0..as_u32(&eval_expr(functions, args[3], env)?)? {
            let mut nested = env.clone();
            nested.insert(idx_name.clone(), Value::U32(idx));
            nested.insert(acc_name.clone(), acc);
            acc = eval_expr(functions, args[4], &nested)?;
        }
        return Ok(acc);
    }
    if let Some(inner) = call_payload(expr, "tail_rec_nat") {
        let args = split_top_args(inner);
        let counter_name = args[0].to_string();
        let acc_name = args[1].to_string();
        let mut counter = as_u32(&eval_expr(functions, args[2], env)?)?;
        let mut acc = eval_expr(functions, args[3], env)?;
        while counter != 0 {
            let mut nested = env.clone();
            nested.insert(counter_name.clone(), Value::U32(counter));
            nested.insert(acc_name.clone(), acc);
            acc = eval_expr(functions, args[4], &nested)?;
            counter = counter.wrapping_sub(1);
        }
        return Ok(acc);
    }
    if let Some(inner) = call_payload(expr, "tuple") {
        let args = split_top_args(inner);
        let left = eval_expr(functions, args[0], env)?;
        let right = eval_expr(functions, args[1], env)?;
        return match (left, right) {
            (Value::Unit, Value::U32(value)) => Ok(Value::ProdUnitU32(value)),
            (Value::U32(left), Value::U32(right)) => Ok(Value::ProdU32((left, right))),
            (Value::ResultUnitU32(left), Value::U32(right)) => {
                Ok(Value::ProdResultUnitU32U32((left, right)))
            }
            (Value::ResultU32U32(left), Value::U32(right)) => {
                Ok(Value::ProdResultU32U32U32((left, right)))
            }
            other => Err(format!("unsupported tuple values {other:?}")),
        };
    }
    if let Some(inner) = call_payload(expr, "list_length") {
        return Ok(Value::U32(match eval_expr(functions, inner, env)? {
            Value::VecU32(values) => values.len() as u32,
            Value::VecRoseTreeU32(values) => values.len() as u32,
            other => return Err(format!("unsupported list_length target {other:?}")),
        }));
    }
    if let Some(inner) = call_payload(expr, "match_pattern") {
        let args = split_top_args(inner);
        return eval_match_pattern(
            functions,
            &eval_expr(functions, args[0], env)?,
            args[1],
            env,
        );
    }
    if let Some(inner) = call_payload(expr, "match_option") {
        return eval_match_option(functions, inner, env);
    }
    if let Some(inner) = call_payload(expr, "match_enum") {
        return eval_match_enum(functions, inner, env);
    }
    if let Some(inner) = call_payload(expr, "result_map_error") {
        let args = split_top_args(inner);
        return match eval_expr(functions, args[0], env)? {
            Value::ResultU32U32(Ok(value)) => Ok(Value::ResultU32U32(Ok(value))),
            Value::ResultU32U32(Err(err)) => {
                let mut nested = env.clone();
                nested.insert(String::from("err"), Value::U32(err));
                Ok(Value::ResultU32U32(Err(as_u32(&eval_expr(
                    functions, args[1], &nested,
                )?)?)))
            }
            other => Err(format!("unsupported result_map_error value {other:?}")),
        };
    }
    Err(format!("unsupported target fingerprint expression: {expr}"))
}

fn eval_add(left: Value, right: Value) -> Result<Value, String> {
    match (left, right) {
        (Value::U32(left), Value::U32(right)) => Ok(Value::U32(left.wrapping_add(right))),
        (Value::U64(left), Value::U64(right)) => Ok(Value::U64(left.wrapping_add(right))),
        (Value::Nat(left), Value::Nat(right)) => Ok(Value::Nat(left + right)),
        (Value::Int(left), Value::Int(right)) => Ok(Value::Int(left + right)),
        other => Err(format!("unsupported add values {other:?}")),
    }
}

fn eval_mul(left: Value, right: Value) -> Result<Value, String> {
    match (left, right) {
        (Value::U32(left), Value::U32(right)) => Ok(Value::U32(left.wrapping_mul(right))),
        (Value::Nat(left), Value::Nat(right)) => Ok(Value::Nat(left * right)),
        (Value::Int(left), Value::Int(right)) => Ok(Value::Int(left * right)),
        other => Err(format!("unsupported mul values {other:?}")),
    }
}

fn eval_sub(left: Value, right: Value) -> Result<Value, String> {
    match (left, right) {
        (Value::U32(left), Value::U32(right)) => Ok(Value::U32(left.wrapping_sub(right))),
        (Value::Nat(left), Value::Nat(right)) => Ok(Value::Nat(left - right)),
        (Value::Int(left), Value::Int(right)) => Ok(Value::Int(left - right)),
        other => Err(format!("unsupported sub values {other:?}")),
    }
}

fn eval_field(target: Value, field: &str) -> Result<Value, String> {
    match (target, field) {
        (Value::Point(point), "x") => Ok(Value::U32(point.x)),
        (Value::Point(point), "y") => Ok(Value::U32(point.y)),
        (Value::BoxedU32(boxed), "value") => Ok(Value::U32(boxed.value)),
        (Value::BoundedProof(proof), "value") => Ok(Value::U32(proof.value)),
        (Value::AddDeltaEnv(env), "delta") => Ok(Value::U32(env.delta)),
        (Value::NestedpayloadU32String(payload), "primary") => {
            Ok(Value::OptionU32(payload.primary))
        }
        (Value::NestedpayloadU32String(payload), "secondary") => {
            Ok(Value::ResultU32U32(payload.secondary.map_err(|_| 0u32)))
        }
        (Value::PairboxU32String(pair), "left") => Ok(Value::U32(pair.left)),
        (Value::PairboxU32String(pair), "right") => Ok(Value::String(pair.right)),
        (Value::PairboxStringU32(pair), "left") => Ok(Value::String(pair.left)),
        (Value::PairboxStringU32(pair), "right") => Ok(Value::U32(pair.right)),
        (Value::RoseTreeU32(tree), "value") => Ok(Value::U32(tree.value)),
        (Value::RoseTreeU32(tree), "children") => Ok(Value::VecRoseTreeU32(tree.children)),
        (other, _) => Err(format!("unsupported field access {other:?}.{field}")),
    }
}

fn eval_struct(functions: &FunctionMap, inner: &str, env: &Env) -> Result<Value, String> {
    let args = split_top_args(inner);
    let name = args[0];
    let fields = args[1..]
        .iter()
        .map(|field| {
            let (field_name, expr) = field
                .split_once('=')
                .ok_or_else(|| format!("malformed struct field {field}"))?;
            Ok((field_name.trim(), eval_expr(functions, expr.trim(), env)?))
        })
        .collect::<Result<Vec<_>, String>>()?;
    match name {
        "Point" => Ok(Value::Point(Point {
            x: as_u32(&fields[0].1)?,
            y: as_u32(&fields[1].1)?,
        })),
        "BoxedU32" => Ok(Value::BoxedU32(BoxedU32 {
            value: as_u32(&fields[0].1)?,
        })),
        "BoundedProof" => Ok(Value::BoundedProof(BoundedProof {
            value: as_u32(&fields[0].1)?,
        })),
        "AddDeltaU32Env" => Ok(Value::AddDeltaEnv(AddDeltaU32Env {
            delta: as_u32(&fields[0].1)?,
        })),
        "PairboxU32String" => Ok(Value::PairboxU32String(PairboxU32String {
            left: as_u32(&fields[0].1)?,
            right: as_string(&fields[1].1)?,
        })),
        "PairboxStringU32" => Ok(Value::PairboxStringU32(PairboxStringU32 {
            left: as_string(&fields[0].1)?,
            right: as_u32(&fields[1].1)?,
        })),
        "NestedpayloadU32String" => Ok(Value::NestedpayloadU32String(NestedpayloadU32String {
            primary: as_option_u32(&fields[0].1)?,
            secondary: match &fields[1].1 {
                Value::ResultU32U32(result) => result.map_err(|_| String::from("lean")),
                Value::ResultU32String(result) => result.clone(),
                other => return Err(format!("unsupported nested payload secondary {other:?}")),
            },
        })),
        "RoseTreeU32" => Ok(Value::RoseTreeU32(RoseTreeU32 {
            value: as_u32(&fields[0].1)?,
            children: as_vec_rosetree_u32(&fields[1].1)?,
        })),
        other => Err(format!("unsupported struct constructor {other}")),
    }
}

fn eval_enum(functions: &FunctionMap, inner: &str, env: &Env) -> Result<Value, String> {
    let args = split_top_args(inner);
    let tag = args[0];
    let payload = args[1..]
        .iter()
        .map(|arg| eval_expr(functions, arg, env))
        .collect::<Result<Vec<_>, _>>()?;
    match tag {
        "Step::Stay" => Ok(Value::Step(Step::Stay)),
        "Step::Jump" => Ok(Value::Step(Step::Jump(as_u32(&payload[0])?))),
        "Choice::First" => Ok(Value::Choice(Choice::First)),
        "Choice::Second" => Ok(Value::Choice(Choice::Second)),
        "PairchoiceU32String::Left" => Ok(Value::PairchoiceU32String(PairchoiceU32String::Left(
            as_u32(&payload[0])?,
        ))),
        "PairchoiceU32String::Right" => Ok(Value::PairchoiceU32String(PairchoiceU32String::Right(
            as_string(&payload[0])?,
        ))),
        "TaggedU32::Missing" => Ok(Value::TaggedU32(TaggedU32::Missing)),
        "TaggedU32::Present" => Ok(Value::TaggedU32(TaggedU32::Present(as_u32(&payload[0])?))),
        "U32FnCase::Inc" => Ok(Value::U32FnCase(U32FnCase::Inc)),
        "U32FnCase::Double" => Ok(Value::U32FnCase(U32FnCase::Double)),
        "U32FnCase::Add" => Ok(Value::U32FnCase(U32FnCase::Add(as_u32(&payload[0])?))),
        "BinaryTreeU32::Leaf" => Ok(Value::BinaryTreeU32(BinaryTreeU32::Leaf)),
        "BinaryTreeU32::Node" => Ok(Value::BinaryTreeU32(BinaryTreeU32::Node(
            Box::new(as_binary_tree_u32(match &payload[0] {
                Value::Boxed(inner) => inner.as_ref(),
                other => return Err(format!("expected boxed tree payload, found {other:?}")),
            })?),
            as_u32(&payload[1])?,
            Box::new(as_binary_tree_u32(match &payload[2] {
                Value::Boxed(inner) => inner.as_ref(),
                other => return Err(format!("expected boxed tree payload, found {other:?}")),
            })?),
        ))),
        "ExprU32::Lit" => Ok(Value::ExprU32(ExprU32::Lit(as_u32(&payload[0])?))),
        "ExprU32::Add" => Ok(Value::ExprU32(ExprU32::Add(
            Box::new(as_expr_u32(match &payload[0] {
                Value::Boxed(inner) => inner.as_ref(),
                other => return Err(format!("expected boxed expr payload, found {other:?}")),
            })?),
            Box::new(as_expr_u32(match &payload[1] {
                Value::Boxed(inner) => inner.as_ref(),
                other => return Err(format!("expected boxed expr payload, found {other:?}")),
            })?),
        ))),
        "EvenNode::Terminal" => Ok(Value::EvenNode(EvenNode::Terminal(as_u32(&payload[0])?))),
        "EvenNode::Step" => Ok(Value::EvenNode(EvenNode::Step(
            as_u32(&payload[0])?,
            Box::new(as_odd_node(match &payload[1] {
                Value::Boxed(inner) => inner.as_ref(),
                other => return Err(format!("expected boxed odd-node payload, found {other:?}")),
            })?),
        ))),
        "OddNode::Terminal" => Ok(Value::OddNode(OddNode::Terminal(as_u32(&payload[0])?))),
        "OddNode::Step" => Ok(Value::OddNode(OddNode::Step(
            as_u32(&payload[0])?,
            Box::new(as_even_node(match &payload[1] {
                Value::Boxed(inner) => inner.as_ref(),
                other => return Err(format!("expected boxed even-node payload, found {other:?}")),
            })?),
        ))),
        other => Err(format!("unsupported enum constructor {other}")),
    }
}

fn eval_match_pattern(
    functions: &FunctionMap,
    target: &Value,
    arms: &str,
    env: &Env,
) -> Result<Value, String> {
    for arm in split_top_level(arms, '|') {
        let (pattern, body) = arm
            .split_once("=>")
            .ok_or_else(|| format!("malformed match_pattern arm {arm}"))?;
        if let Some(bindings) = match_pattern_bindings(pattern.trim(), target)
            .or_else(|| match_enum_bindings(pattern.trim(), target))
        {
            let mut nested = env.clone();
            for (name, value) in bindings {
                nested.insert(name, value);
            }
            return eval_expr(functions, body.trim(), &nested);
        }
    }
    Err(format!("no match_pattern arm matched {target:?}"))
}

fn eval_match_option(functions: &FunctionMap, inner: &str, env: &Env) -> Result<Value, String> {
    let args = split_top_args(inner);
    let target = eval_expr(functions, args[0], env)?;
    let arms = args[1];
    let parts = split_top_level(arms, '|');
    match target {
        Value::OptionU32(None) | Value::OptionStep(None) => {
            let body = parts[0]
                .split_once("=>")
                .ok_or_else(|| format!("malformed match_option none arm {}", parts[0]))?
                .1;
            eval_expr(functions, body.trim(), env)
        }
        Value::OptionU32(Some(value)) => {
            let (head, body) = parts[1]
                .split_once("=>")
                .ok_or_else(|| format!("malformed match_option some arm {}", parts[1]))?;
            let binder = call_payload(head, "some")
                .ok_or_else(|| format!("malformed match_option binder {head}"))?;
            let mut nested = env.clone();
            nested.insert(binder.to_string(), Value::U32(value));
            eval_expr(functions, body.trim(), &nested)
        }
        Value::OptionStep(Some(value)) => {
            let (head, body) = parts[1]
                .split_once("=>")
                .ok_or_else(|| format!("malformed match_option some arm {}", parts[1]))?;
            let binder = call_payload(head, "some")
                .ok_or_else(|| format!("malformed match_option binder {head}"))?;
            let mut nested = env.clone();
            nested.insert(binder.to_string(), Value::Step(value));
            eval_expr(functions, body.trim(), &nested)
        }
        other => Err(format!("unsupported match_option target {other:?}")),
    }
}

fn eval_match_enum(functions: &FunctionMap, inner: &str, env: &Env) -> Result<Value, String> {
    let args = split_top_args(inner);
    let target = eval_expr(functions, args[0], env)?;
    for arm in split_top_level(args[1], '|') {
        let (pattern, body) = arm
            .split_once("=>")
            .ok_or_else(|| format!("malformed match_enum arm {arm}"))?;
        if let Some(bindings) = match_enum_bindings(pattern.trim(), &target) {
            let mut nested = env.clone();
            for (name, value) in bindings {
                nested.insert(name, value);
            }
            return eval_expr(functions, body.trim(), &nested);
        }
    }
    Err(format!("no match_enum arm matched {target:?}"))
}
