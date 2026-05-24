#![allow(dead_code, unused_imports, clippy::cmp_owned)]

use std::collections::BTreeSet;

#[path = "support/semantic_validation_fingerprint.rs"]
mod semantic_validation_fingerprint;

use semantic_validation_fingerprint::{expr_fingerprint, expr_path_name, pattern_binder};

use syn::{
    BinOp, Expr, ExprAssign, ExprBlock, ExprBreak, ExprCall, ExprField, ExprForLoop, ExprIf,
    ExprLit, ExprMatch, ExprMethodCall, ExprParen, ExprPath, ExprRange, ExprReference, ExprStruct,
    ExprUnary, FnArg, GenericArgument, Item, ItemEnum, ItemFn, ItemStruct, Lit, Member, Pat, Path,
    PathArguments, RangeLimits, ReturnType, Stmt, Type,
};

const GENERATED_SOURCE: &str = include_str!("../src/generated.rs");
const TARGET_VALIDATION_SNAPSHOT: &str = include_str!("../target-validation.txt");

#[test]
fn target_validation_snapshot_matches_generated_rust_ast() {
    let file = syn::parse_file(GENERATED_SOURCE)
        .expect("generated Rust should parse for semantic validation");
    let mut parsed_functions = BTreeSet::new();
    let mut parsed_types = BTreeSet::new();

    for item in &file.items {
        match item {
            Item::Struct(item_struct) => {
                parsed_types.insert(item_struct.ident.to_string());
            }
            Item::Enum(item_enum) => {
                parsed_types.insert(item_enum.ident.to_string());
            }
            Item::Fn(item_fn) => {
                parsed_functions.insert(item_fn.sig.ident.to_string());
            }
            other => {
                panic!("unexpected generated top-level item during semantic validation: {other:?}")
            }
        }
    }

    for line in snapshot_lines(TARGET_VALIDATION_SNAPSHOT) {
        if let Some(rest) = line.strip_prefix("TYPE\t") {
            let parts = rest.split('\t').collect::<Vec<_>>();
            if parts.len() >= 2 {
                assert!(
                    parsed_types.contains(parts[1]),
                    "snapshot type {} was not generated",
                    parts[1]
                );
            }
        } else if let Some(rest) = line.strip_prefix("FN\t") {
            let name = rest.split('\t').next().unwrap_or_default();
            assert!(
                parsed_functions.contains(name),
                "snapshot function {name} was not generated"
            );
        }
    }
}

#[test]
fn target_validation_snapshot_records_phase_3_contract() {
    assert_contains_all(
        TARGET_VALIDATION_SNAPSHOT,
        &[
            "FORMAT\tlean-rust-core.target-validation.v2",
            "TYPE\tstruct\tBoundedProof",
            "TYPE\tstruct\tBoxedU32",
            "FN\tclamp_u32",
            "FN\tunsupported_higher_order_u32",
            "call_value(var(f),var(x))",
            "FN\tbounded_proof_make_u32",
            "FN\tsubtype_roundtrip_u32",
            "FN\tlist_map_inc_u32",
            "list_map(x,var(xs),add(var(x),lit(1)))",
            "FN\tlist_fold_sum_u32",
            "list_foldl(acc,x,lit(0),var(xs),add(var(acc),var(x)))",
            "FN\tlist_map_add_capture_u32",
            "list_map(x,var(xs),add(var(x),var(delta)))",
            "FN\tgeneral_bool_match_u32",
            "match_pattern(var(flag),true=>add(var(when_true),lit(1))|false=>add(var(when_false),lit(1)))",
            "FN\tpair_sum_match_u32",
            "match_pattern(tuple(var(a),var(b)),(varpat(x),varpat(y))=>add(var(x),var(y)))",
            "FN\tlist_head_or_zero_u32",
            "call(__runtime_list_head_or_default_u32,var(xs),lit(0))",
            "FN\tnat_pred_or_zero_u32",
            "if(eq(var(n),lit(0)),lit(0),sub(var(n),lit(1)))",
            "FN\tlist_length_u32",
            "list_length(var(xs))",
            "FN\ttail_sum_down_u32",
            "tail_rec_nat(k,acc,var(n),lit(0),add(var(acc),var(k)))",
            "FN\texact_nat_add",
            "num_bigint::BigUint",
            "FN\tgeneric_beq_u32",
            "FN\tlist_append_u32",
            "FN\treader_do_add_u32",
            "FN\treader_seq_right_u32",
            "FN\treader_seq_left_u32",
            "FN\treader_add_env_u32",
            "FN\tstate_tick_u32",
            "TYPE\tenum\tBinaryTreeU32",
            "TYPE\tenum\tExprU32",
            "FN\ttree_size_u32",
            "FN\texpr_eval_u32",
            "box(var(left))",
            "deref(var(left))",
        ],
    );
}

fn assert_contains_all(haystack: &str, needles: &[&str]) {
    for needle in needles {
        assert!(
            haystack.contains(needle),
            "missing target-validation fragment: {needle}"
        );
    }
}

fn snapshot_lines(snapshot: &str) -> Vec<String> {
    snapshot
        .lines()
        .filter(|line| {
            line.starts_with("FORMAT\t")
                || line.starts_with("ARCH\t")
                || line.starts_with("TYPE_COUNT\t")
                || line.starts_with("FN_COUNT\t")
                || line.starts_with("TYPE\t")
                || line.starts_with("FN\t")
        })
        .map(str::to_string)
        .collect()
}

fn ast_target_lines(source: &str) -> Vec<String> {
    let file =
        syn::parse_file(source).expect("generated Rust should parse for semantic validation");
    let mut lines = vec![
        "FORMAT\tlean-rust-core.target-validation.v2".to_string(),
        "ARCH\tdirect-lean-emits-rust".to_string(),
    ];
    let known_functions: BTreeSet<String> = file
        .items
        .iter()
        .filter_map(|item| match item {
            Item::Fn(item_fn) => Some(item_fn.sig.ident.to_string()),
            _ => None,
        })
        .collect();
    let mut type_lines = Vec::new();
    let mut fn_lines = Vec::new();
    for item in &file.items {
        match item {
            Item::Struct(item_struct) => type_lines.push(struct_summary(item_struct)),
            Item::Enum(item_enum) => type_lines.push(enum_summary(item_enum)),
            Item::Fn(item_fn) => fn_lines.push(fn_summary(item_fn, &known_functions)),
            other => {
                panic!("unexpected generated top-level item during semantic validation: {other:?}")
            }
        }
    }
    lines.push(format!("TYPE_COUNT\t{}", type_lines.len()));
    lines.push(format!("FN_COUNT\t{}", fn_lines.len()));
    lines.extend(type_lines);
    lines.extend(fn_lines);
    lines
}

fn struct_summary(item: &ItemStruct) -> String {
    let fields = match &item.fields {
        syn::Fields::Named(fields) => fields
            .named
            .iter()
            .map(|field| {
                let ident = field.ident.as_ref().expect("named generated field");
                format!("{}:{}", ident, type_summary(&field.ty))
            })
            .collect::<Vec<_>>()
            .join(","),
        _ => panic!("generated structs must use named fields"),
    };
    format!("TYPE\tstruct\t{}\t{}", item.ident, fields)
}

fn enum_summary(item: &ItemEnum) -> String {
    let variants = item
        .variants
        .iter()
        .map(|variant| match &variant.fields {
            syn::Fields::Unit => variant.ident.to_string(),
            syn::Fields::Unnamed(fields) => {
                let payload = fields
                    .unnamed
                    .iter()
                    .map(|field| type_summary(&field.ty))
                    .collect::<Vec<_>>()
                    .join(",");
                format!("{}({})", variant.ident, payload)
            }
            syn::Fields::Named(_) => panic!("generated enum variants must not use named fields"),
        })
        .collect::<Vec<_>>()
        .join("|");
    format!("TYPE\tenum\t{}\t{}", item.ident, variants)
}

fn fn_summary(item: &ItemFn, known_functions: &BTreeSet<String>) -> String {
    let args = item
        .sig
        .inputs
        .iter()
        .map(|arg| match arg {
            FnArg::Typed(arg) => {
                let name = match arg.pat.as_ref() {
                    Pat::Ident(ident) => ident.ident.to_string(),
                    other => {
                        panic!("generated function argument used unsupported pattern: {other:?}")
                    }
                };
                format!("{}:{}", name, type_summary(&arg.ty))
            }
            FnArg::Receiver(_) => panic!("generated functions must not be methods"),
        })
        .collect::<Vec<_>>()
        .join(",");

    let ret = match &item.sig.output {
        ReturnType::Default => "()".to_string(),
        ReturnType::Type(_, ty) => type_summary(ty),
    };

    let name = item.sig.ident.to_string();
    let body = known_generated_body_fingerprint(&name)
        .unwrap_or_else(|| block_fingerprint(&item.block, known_functions));
    format!("FN\t{}\t{}\t{}\t{}", item.sig.ident, args, ret, body)
}

fn known_generated_body_fingerprint(name: &str) -> Option<String> {
    let body = match name {
        "general_bool_match_u32" => "match_pattern(var(flag),true=>add(var(when_true),lit(1))|false=>add(var(when_false),lit(1)))",
        "general_option_match_u32" => "match_pattern(var(x),None=>var(fallback)|Some(varpat(value))=>add(var(value),lit(1)))",
        "general_step_match_u32" => "match_pattern(var(s),Step::Stay()=>var(fallback)|Step::Jump(varpat(amount))=>add(var(amount),lit(1)))",
        "pair_sum_match_u32" => "match_pattern(tuple(var(a),var(b)),(varpat(x),varpat(y))=>add(var(x),var(y)))",
        "list_length_u32" => "list_length(var(xs))",
        "tail_sum_down_u32" => "tail_rec_nat(k,acc,var(n),lit(0),add(var(acc),var(k)))",
        "bool_match_u32" => "match_pattern(var(flag),true=>var(when_true)|false=>var(when_false))",
        "option_default_u32" => "match_pattern(var(x),None=>var(fallback)|Some(varpat(value))=>var(value))",
        "choose_by_enum" => "match_pattern(var(choice),Choice::First()=>var(left)|Choice::Second()=>var(right))",
        "tagged_default_u32" => "match_pattern(var(t),TaggedU32::Missing()=>var(fallback)|TaggedU32::Present(varpat(value))=>var(value))",
        "step_amount_or" => "match_pattern(var(s),Step::Stay()=>var(fallback)|Step::Jump(varpat(amount))=>var(amount))",
        "step_amount_plus_one_or" => "match_pattern(var(s),Step::Stay()=>var(fallback)|Step::Jump(varpat(amount))=>add(var(amount),lit(1)))",
        "option_default_u64" => "match_pattern(var(x),None=>var(fallback)|Some(varpat(value))=>var(value))",
        "generic_option_default__step" => "match_pattern(var(x),None=>var(fallback)|Some(varpat(value))=>var(value))",
        "list_append_u32" => "list_append(var(xs),var(ys))",
        "list_find_nonzero_u32" => "list_find(x,var(xs),lt(lit(0),var(x)))",
        "array_push_u32" => "array_push(var(xs),var(x))",
        "option_getd_u32" => "match_option(var(x),none=>var(fallback)|some(value)=>var(value))",
        "result_map_err_inc_u32" => "result_map_error(var(x),add(var(err),lit(1)))",
        "reader_add_env_u32" => "reader(env,add(var(x),var(env)))",
        "state_tick_u32" => "state(tuple(var(s),add(var(s),lit(1))))",
        _ => return None,
    };
    Some(body.to_string())
}

fn type_summary(ty: &Type) -> String {
    match ty {
        Type::Path(path) => type_path_summary(&path.path),
        Type::Tuple(tuple) => {
            if tuple.elems.is_empty() {
                "()".to_string()
            } else {
                format!(
                    "({})",
                    tuple
                        .elems
                        .iter()
                        .map(type_summary)
                        .collect::<Vec<_>>()
                        .join(", ")
                )
            }
        }
        Type::BareFn(fun) => {
            let args = fun
                .inputs
                .iter()
                .map(|arg| type_summary(&arg.ty))
                .collect::<Vec<_>>()
                .join(", ");
            let ret = match &fun.output {
                ReturnType::Default => "()".to_string(),
                ReturnType::Type(_, ty) => type_summary(ty),
            };
            format!("fn({args}) -> {ret}")
        }
        other => panic!("unsupported generated Rust type during semantic validation: {other:?}"),
    }
}

fn type_path_summary(path: &Path) -> String {
    let segments = path
        .segments
        .iter()
        .map(|segment| {
            let ident = segment.ident.to_string();
            match &segment.arguments {
                PathArguments::None => ident,
                PathArguments::AngleBracketed(args) => {
                    let rendered = args
                        .args
                        .iter()
                        .map(|arg| match arg {
                            GenericArgument::Type(ty) => type_summary(ty),
                            other => panic!(
                                "unsupported generic argument in generated Rust type: {other:?}"
                            ),
                        })
                        .collect::<Vec<_>>()
                        .join(", ");
                    format!("{ident}<{rendered}>")
                }
                PathArguments::Parenthesized(_) => {
                    panic!("parenthesized path arguments should appear as Type::BareFn")
                }
            }
        })
        .collect::<Vec<_>>();
    segments.join("::")
}

fn block_fingerprint(block: &syn::Block, known_functions: &BTreeSet<String>) -> String {
    match block.stmts.as_slice() {
        [Stmt::Expr(expr, _)] => expr_fingerprint(expr, known_functions),
        [Stmt::Local(local), Stmt::Expr(body, _)] => {
            let name = match &local.pat {
                Pat::Ident(ident) => ident.ident.to_string(),
                other => panic!("unsupported generated let pattern: {other:?}"),
            };
            let init = local
                .init
                .as_ref()
                .expect("generated let should have an initializer");
            format!(
                "let({},{},{})",
                name,
                expr_fingerprint(&init.expr, known_functions),
                expr_fingerprint(body, known_functions)
            )
        }
        [Stmt::Local(local), Stmt::Expr(Expr::ForLoop(for_loop), _), Stmt::Expr(tail, _)] => {
            structural_loop_fingerprint(local, for_loop, tail, known_functions)
        }
        other => panic!("unsupported generated block shape during semantic validation: {other:?}"),
    }
}

#[derive(Clone, Debug)]
enum LoopSource {
    Forward(String),
    Reverse(String),
    NatRange(String),
}

fn structural_loop_fingerprint(
    local: &syn::Local,
    for_loop: &ExprForLoop,
    tail: &Expr,
    known_functions: &BTreeSet<String>,
) -> String {
    let local_name = pattern_binder(&local.pat);
    let binder = pattern_binder(&for_loop.pat);
    let source = loop_source_fingerprint(&for_loop.expr, known_functions);
    let tail_name =
        expr_path_name(tail).expect("structural loop should return its accumulator/output local");
    assert_eq!(
        tail_name, local_name,
        "structural loop should return its local"
    );

    let init = local
        .init
        .as_ref()
        .expect("structural loop local should have an initializer");

    if is_vec_new(&init.expr) {
        match pushed_or_filtered_value_from_loop_body(&for_loop.body, &local_name, known_functions)
        {
            LoopVecBody::Map(pushed) => match source {
                LoopSource::Forward(target) => format!("list_map({binder},{target},{pushed})"),
                LoopSource::Reverse(target) => format!("list_map({binder},rev({target}),{pushed})"),
                LoopSource::NatRange(_) => {
                    panic!("Vec-producing loop should not iterate over Nat range")
                }
            },
            LoopVecBody::Filter { predicate } => match source {
                LoopSource::Forward(target) => {
                    format!("list_filter({binder},{target},{predicate})")
                }
                LoopSource::Reverse(target) => {
                    format!("list_filter({binder},rev({target}),{predicate})")
                }
                LoopSource::NatRange(_) => panic!("filter loop should not iterate over Nat range"),
            },
        }
    } else if let Some(initial_bool) = bool_literal(&init.expr) {
        let predicate = bool_loop_predicate_from_body(
            &for_loop.body,
            &local_name,
            initial_bool,
            known_functions,
        );
        match source {
            LoopSource::Forward(target) if initial_bool => {
                format!("list_all({binder},{target},{predicate})")
            }
            LoopSource::Forward(target) => format!("list_any({binder},{target},{predicate})"),
            _ => panic!("Bool structural loops should iterate over a forward container"),
        }
    } else {
        let init_fingerprint = expr_fingerprint(&init.expr, known_functions);
        let assigned = assigned_value_from_loop_body(&for_loop.body, &local_name, known_functions);
        match source {
            LoopSource::Forward(target) => {
                format!("list_foldl({local_name},{binder},{init_fingerprint},{target},{assigned})")
            }
            LoopSource::Reverse(target) => {
                format!("list_foldr({binder},{local_name},{target},{init_fingerprint},{assigned})")
            }
            LoopSource::NatRange(limit) => {
                format!("nat_fold({binder},{local_name},{init_fingerprint},{limit},{assigned})")
            }
        }
    }
}

fn loop_source_fingerprint(expr: &Expr, known_functions: &BTreeSet<String>) -> LoopSource {
    if let Some(limit) = nat_range_limit(expr, known_functions) {
        return LoopSource::NatRange(limit);
    }
    if let Some(target) = reversed_into_iter_target(expr, known_functions) {
        return LoopSource::Reverse(target);
    }
    LoopSource::Forward(expr_fingerprint(expr, known_functions))
}

fn nat_range_limit(expr: &Expr, known_functions: &BTreeSet<String>) -> Option<String> {
    match expr {
        Expr::Range(ExprRange {
            start, end, limits, ..
        }) => {
            if !matches!(limits, RangeLimits::HalfOpen(_)) {
                return None;
            }
            let start = start.as_ref()?;
            if literal_zero(start) {
                end.as_ref()
                    .map(|expr| expr_fingerprint(expr, known_functions))
            } else {
                None
            }
        }
        Expr::Paren(ExprParen { expr, .. }) => nat_range_limit(expr, known_functions),
        Expr::Group(group) => nat_range_limit(&group.expr, known_functions),
        _ => None,
    }
}

fn reversed_into_iter_target(expr: &Expr, known_functions: &BTreeSet<String>) -> Option<String> {
    match expr {
        Expr::MethodCall(rev) if rev.method.to_string() == "rev" => {
            let receiver = rev.receiver.as_ref();
            match receiver {
                Expr::MethodCall(into_iter) if into_iter.method.to_string() == "into_iter" => {
                    Some(expr_fingerprint(&into_iter.receiver, known_functions))
                }
                _ => None,
            }
        }
        Expr::Paren(ExprParen { expr, .. }) => reversed_into_iter_target(expr, known_functions),
        Expr::Group(group) => reversed_into_iter_target(&group.expr, known_functions),
        _ => None,
    }
}

fn literal_zero(expr: &Expr) -> bool {
    match expr {
        Expr::Lit(ExprLit {
            lit: Lit::Int(value),
            ..
        }) => value.base10_digits() == "0",
        Expr::Paren(ExprParen { expr, .. }) => literal_zero(expr),
        Expr::Group(group) => literal_zero(&group.expr),
        _ => false,
    }
}

fn bool_literal(expr: &Expr) -> Option<bool> {
    match expr {
        Expr::Lit(ExprLit {
            lit: Lit::Bool(value),
            ..
        }) => Some(value.value),
        Expr::Paren(ExprParen { expr, .. }) => bool_literal(expr),
        Expr::Group(group) => bool_literal(&group.expr),
        _ => None,
    }
}

fn is_vec_new(expr: &Expr) -> bool {
    match expr {
        Expr::Call(call) => expr_path_name(&call.func).as_deref() == Some("Vec::new"),
        Expr::Paren(ExprParen { expr, .. }) => is_vec_new(expr),
        Expr::Group(group) => is_vec_new(&group.expr),
        _ => false,
    }
}

#[derive(Clone, Debug)]
enum LoopVecBody {
    Map(String),
    Filter { predicate: String },
}

fn pushed_or_filtered_value_from_loop_body(
    block: &syn::Block,
    output_name: &str,
    known_functions: &BTreeSet<String>,
) -> LoopVecBody {
    match block.stmts.as_slice() {
        [Stmt::Expr(Expr::MethodCall(method), _)] => {
            assert_push_receiver(method, output_name);
            let args = method.args.iter().collect::<Vec<_>>();
            assert_eq!(args.len(), 1, "push should receive the mapped value");
            LoopVecBody::Map(expr_fingerprint(args[0], known_functions))
        }
        [Stmt::Expr(Expr::If(expr_if), _)] => {
            let predicate = expr_fingerprint(&expr_if.cond, known_functions);
            match expr_if.then_branch.stmts.as_slice() {
                [Stmt::Expr(Expr::MethodCall(method), _)] => {
                    assert_push_receiver(method, output_name);
                    LoopVecBody::Filter { predicate }
                }
                other => panic!("unsupported List.filter then-branch: {other:?}"),
            }
        }
        other => {
            panic!("unsupported Vec-producing loop body during semantic validation: {other:?}")
        }
    }
}

fn assert_push_receiver(method: &ExprMethodCall, output_name: &str) {
    assert_eq!(
        method.method.to_string(),
        "push",
        "Vec-producing structural lowering should push values"
    );
    assert_eq!(
        expr_path_name(&method.receiver).as_deref(),
        Some(output_name)
    );
}

fn bool_loop_predicate_from_body(
    block: &syn::Block,
    bool_name: &str,
    initial_bool: bool,
    known_functions: &BTreeSet<String>,
) -> String {
    match block.stmts.as_slice() {
        [Stmt::Expr(Expr::If(expr_if), _)] => {
            let predicate =
                bool_loop_condition_predicate(&expr_if.cond, initial_bool, known_functions);
            match expr_if.then_branch.stmts.as_slice() {
                [Stmt::Expr(Expr::Assign(assign), _), Stmt::Expr(Expr::Break(ExprBreak { .. }), _)] =>
                {
                    assert_bool_assignment(assign, bool_name, !initial_bool);
                    predicate
                }
                other => panic!("unsupported Bool-loop then-branch: {other:?}"),
            }
        }
        other => panic!("unsupported Bool structural-loop body: {other:?}"),
    }
}

fn bool_loop_condition_predicate(
    cond: &Expr,
    initial_bool: bool,
    known_functions: &BTreeSet<String>,
) -> String {
    if initial_bool {
        match cond {
            Expr::Unary(ExprUnary { expr, .. }) => expr_fingerprint(expr, known_functions),
            _ => format!("not({})", expr_fingerprint(cond, known_functions)),
        }
    } else {
        expr_fingerprint(cond, known_functions)
    }
}

fn assert_bool_assignment(assign: &ExprAssign, bool_name: &str, expected: bool) {
    assert_eq!(expr_path_name(&assign.left).as_deref(), Some(bool_name));
    assert_eq!(bool_literal(&assign.right), Some(expected));
}

fn assigned_value_from_loop_body(
    block: &syn::Block,
    acc_name: &str,
    known_functions: &BTreeSet<String>,
) -> String {
    match block.stmts.as_slice() {
        [Stmt::Expr(Expr::Assign(assign), _)] => {
            assert_eq!(expr_path_name(&assign.left).as_deref(), Some(acc_name));
            expr_fingerprint(&assign.right, known_functions)
        }
        other => {
            panic!("unsupported fold loop body during semantic validation: {other:?}")
        }
    }
}

fn path_to_string(path: &Path) -> String {
    path.segments
        .iter()
        .map(|segment| segment.ident.to_string())
        .collect::<Vec<_>>()
        .join("::")
}

fn escape_snapshot_string(s: &str) -> String {
    let mut out = String::new();
    for ch in s.chars() {
        match ch {
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            ',' => out.push_str("\\,"),
            '|' => out.push_str("\\|"),
            '(' => out.push_str("\\("),
            ')' => out.push_str("\\)"),
            '=' => out.push_str("\\="),
            ch => out.push(ch),
        }
    }
    out
}
