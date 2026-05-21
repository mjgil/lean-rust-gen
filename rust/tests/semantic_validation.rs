use std::collections::BTreeSet;

use syn::{
    BinOp, Expr, ExprBlock, ExprCall, ExprField, ExprIf, ExprLit, ExprMatch, ExprMethodCall,
    ExprParen, ExprPath, ExprStruct, FnArg, GenericArgument, Item, ItemEnum, ItemFn, ItemStruct,
    Lit, Member, Pat, Path, PathArguments, ReturnType, Stmt, Type,
};

const GENERATED_SOURCE: &str = include_str!("../src/generated.rs");
const TARGET_VALIDATION_SNAPSHOT: &str = include_str!("../target-validation.txt");

#[test]
fn target_validation_snapshot_matches_generated_rust_ast() {
    let expected = snapshot_lines(TARGET_VALIDATION_SNAPSHOT);
    let actual = ast_target_lines(GENERATED_SOURCE);

    assert_eq!(
        actual, expected,
        "parsed Rust target-IR summary diverged from Lean-generated target-validation snapshot"
    );
}

#[test]
fn target_validation_snapshot_records_phase_3_contract() {
    assert!(TARGET_VALIDATION_SNAPSHOT.contains("FORMAT\tlean-rust-core.target-validation.v1"));
    assert!(TARGET_VALIDATION_SNAPSHOT.contains("FN\tclamp_u32"));
    assert!(TARGET_VALIDATION_SNAPSHOT.contains("FN\tunsupported_higher_order_u32"));
    assert!(TARGET_VALIDATION_SNAPSHOT.contains("call_value(var(f),var(x))"));
    assert!(TARGET_VALIDATION_SNAPSHOT.contains("TYPE\tstruct\tBoxedU32"));
}

fn snapshot_lines(snapshot: &str) -> Vec<String> {
    let mut lines = Vec::new();
    for line in snapshot.lines() {
        if line.starts_with("FORMAT\t")
            || line.starts_with("ARCH\t")
            || line.starts_with("TYPE_COUNT\t")
            || line.starts_with("FN_COUNT\t")
            || line.starts_with("TYPE\t")
            || line.starts_with("FN\t")
        {
            lines.push(line.to_string());
        }
    }
    lines
}

fn ast_target_lines(source: &str) -> Vec<String> {
    let file =
        syn::parse_file(source).expect("generated Rust should parse for semantic validation");
    let mut lines = vec![
        "FORMAT\tlean-rust-core.target-validation.v1".to_string(),
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

    let body = block_fingerprint(&item.block, known_functions);
    format!("FN\t{}\t{}\t{}\t{}", item.sig.ident, args, ret, body)
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
        other => panic!("unsupported generated block shape during semantic validation: {other:?}"),
    }
}

fn expr_fingerprint(expr: &Expr, known_functions: &BTreeSet<String>) -> String {
    match expr {
        Expr::Paren(ExprParen { expr, .. }) => expr_fingerprint(expr, known_functions),
        Expr::Group(group) => expr_fingerprint(&group.expr, known_functions),
        Expr::Path(path) => path_expr_fingerprint(path),
        Expr::Lit(lit) => literal_fingerprint(lit),
        Expr::Tuple(tuple) if tuple.elems.is_empty() => "unit".to_string(),
        Expr::If(expr_if) => if_fingerprint(expr_if, known_functions),
        Expr::Binary(binary) => binary_fingerprint(binary, known_functions),
        Expr::MethodCall(method) => method_call_fingerprint(method, known_functions),
        Expr::Call(call) => call_fingerprint(call, known_functions),
        Expr::Struct(item) => struct_expr_fingerprint(item, known_functions),
        Expr::Field(field) => field_fingerprint(field, known_functions),
        Expr::Match(item) => match_fingerprint(item, known_functions),
        Expr::Block(ExprBlock { block, .. }) => block_fingerprint(block, known_functions),
        other => {
            panic!("unsupported generated Rust expression during semantic validation: {other:?}")
        }
    }
}

fn path_expr_fingerprint(path: &ExprPath) -> String {
    let path = path_to_string(&path.path);
    match path.as_str() {
        "None" => "none".to_string(),
        _ if path.contains("::") => format!("enum({path})"),
        _ => format!("var({path})"),
    }
}

fn literal_fingerprint(lit: &ExprLit) -> String {
    match &lit.lit {
        Lit::Bool(value) => format!("bool({})", value.value),
        Lit::Int(value) => format!("lit({})", value.base10_digits()),
        Lit::Char(value) => format!("char({})", value.value() as u32),
        Lit::Str(value) => format!("string({})", escape_snapshot_string(&value.value())),
        other => panic!("unsupported generated literal during semantic validation: {other:?}"),
    }
}

fn if_fingerprint(item: &ExprIf, known_functions: &BTreeSet<String>) -> String {
    let cond = expr_fingerprint(&item.cond, known_functions);
    let then_branch = block_fingerprint(&item.then_branch, known_functions);
    let else_branch = item
        .else_branch
        .as_ref()
        .map(|(_, expr)| expr_fingerprint(expr, known_functions))
        .expect("generated if expressions must have else branches");
    format!("if({cond},{then_branch},{else_branch})")
}

fn binary_fingerprint(item: &syn::ExprBinary, known_functions: &BTreeSet<String>) -> String {
    let op = match &item.op {
        BinOp::Eq(_) => "eq",
        BinOp::Lt(_) => "lt",
        BinOp::Le(_) => "le",
        BinOp::Gt(_) => "gt",
        BinOp::Ge(_) => "ge",
        BinOp::Add(_) => "add",
        BinOp::Sub(_) => "sub",
        BinOp::Mul(_) => "mul",
        BinOp::And(_) => "and",
        BinOp::Or(_) => "or",
        other => panic!("unsupported generated binary op during semantic validation: {other:?}"),
    };
    format!(
        "{}({},{})",
        op,
        expr_fingerprint(&item.left, known_functions),
        expr_fingerprint(&item.right, known_functions)
    )
}

fn method_call_fingerprint(item: &ExprMethodCall, known_functions: &BTreeSet<String>) -> String {
    let op = match item.method.to_string().as_str() {
        "wrapping_add" => "add",
        "wrapping_sub" => "sub",
        "wrapping_mul" => "mul",
        other => panic!("unsupported generated method call during semantic validation: {other}"),
    };
    let args = item.args.iter().collect::<Vec<_>>();
    assert_eq!(args.len(), 1, "generated wrapping calls should be binary");
    format!(
        "{}({},{})",
        op,
        expr_fingerprint(&item.receiver, known_functions),
        expr_fingerprint(args[0], known_functions)
    )
}

fn call_fingerprint(item: &ExprCall, known_functions: &BTreeSet<String>) -> String {
    let args = item
        .args
        .iter()
        .map(|arg| expr_fingerprint(arg, known_functions))
        .collect::<Vec<_>>();

    if let Some(path) = expr_path_name(&item.func) {
        match path.as_str() {
            "Some" => return format!("some({})", args.join(",")),
            "Ok" => return format!("ok({})", args.join(",")),
            "Err" => return format!("err({})", args.join(",")),
            _ if path.contains("::") => {
                if args.is_empty() {
                    return format!("enum({path})");
                }
                return format!("enum({},{})", path, args.join(","));
            }
            _ if known_functions.contains(&path) => {
                return format!("call({},{})", path, args.join(","));
            }
            _ => {}
        }
    }

    format!(
        "call_value({},{})",
        expr_fingerprint(&item.func, known_functions),
        args.join(",")
    )
}

fn struct_expr_fingerprint(item: &ExprStruct, known_functions: &BTreeSet<String>) -> String {
    let fields = item
        .fields
        .iter()
        .map(|field| {
            let name = match &field.member {
                Member::Named(ident) => ident.to_string(),
                Member::Unnamed(index) => index.index.to_string(),
            };
            format!(
                "{}={}",
                name,
                expr_fingerprint(&field.expr, known_functions)
            )
        })
        .collect::<Vec<_>>()
        .join(",");
    format!("struct({},{})", path_to_string(&item.path), fields)
}

fn field_fingerprint(item: &ExprField, known_functions: &BTreeSet<String>) -> String {
    let member = match &item.member {
        Member::Named(ident) => ident.to_string(),
        Member::Unnamed(index) => index.index.to_string(),
    };
    format!(
        "field({},{})",
        expr_fingerprint(&item.base, known_functions),
        member
    )
}

fn match_fingerprint(item: &ExprMatch, known_functions: &BTreeSet<String>) -> String {
    let target = expr_fingerprint(&item.expr, known_functions);
    let arms = item
        .arms
        .iter()
        .map(|arm| {
            (
                pattern_summary(&arm.pat),
                expr_fingerprint(&arm.body, known_functions),
            )
        })
        .collect::<Vec<_>>();

    let true_branch = arms.iter().find_map(|(pat, body)| match pat {
        PatternSummary::Bool(true) => Some(body.clone()),
        _ => None,
    });
    let false_branch = arms.iter().find_map(|(pat, body)| match pat {
        PatternSummary::Bool(false) => Some(body.clone()),
        _ => None,
    });
    if let (Some(true_branch), Some(false_branch)) = (true_branch, false_branch) {
        return format!("match_bool({target},{true_branch},{false_branch})");
    }

    let none_branch = arms.iter().find_map(|(pat, body)| match pat {
        PatternSummary::None => Some(body.clone()),
        _ => None,
    });
    let some_branch = arms.iter().find_map(|(pat, body)| match pat {
        PatternSummary::Some(binder) => Some((binder.clone(), body.clone())),
        _ => None,
    });
    if let (Some(none_branch), Some((binder, some_body))) = (none_branch, some_branch) {
        return format!("match_option({target},none=>{none_branch}|some({binder})=>{some_body})");
    }

    let rendered = arms
        .iter()
        .map(|(pat, body)| match pat {
            PatternSummary::Enum { path, binders } => {
                format!("{}({})=>{}", path, binders.join(","), body)
            }
            other => panic!("unsupported mixed generated match pattern: {other:?}"),
        })
        .collect::<Vec<_>>()
        .join("|");
    format!("match_enum({target},{rendered})")
}

#[derive(Clone, Debug)]
enum PatternSummary {
    Bool(bool),
    None,
    Some(String),
    Enum { path: String, binders: Vec<String> },
}

fn pattern_summary(pat: &Pat) -> PatternSummary {
    match pat {
        Pat::Lit(lit) => match &lit.lit {
            Lit::Bool(value) => PatternSummary::Bool(value.value),
            other => panic!("unsupported literal pattern in generated match: {other:?}"),
        },
        Pat::Path(path) => {
            let path = path_to_string(&path.path);
            if path == "None" {
                PatternSummary::None
            } else {
                PatternSummary::Enum {
                    path,
                    binders: Vec::new(),
                }
            }
        }
        Pat::TupleStruct(tuple) => {
            let path = path_to_string(&tuple.path);
            let binders = tuple.elems.iter().map(pattern_binder).collect::<Vec<_>>();
            if path == "Some" {
                assert_eq!(binders.len(), 1, "Option::Some should bind one value");
                PatternSummary::Some(binders[0].clone())
            } else {
                PatternSummary::Enum { path, binders }
            }
        }
        other => {
            panic!("unsupported generated match pattern during semantic validation: {other:?}")
        }
    }
}

fn pattern_binder(pat: &Pat) -> String {
    match pat {
        Pat::Ident(ident) => ident.ident.to_string(),
        other => panic!("unsupported generated payload binder pattern: {other:?}"),
    }
}

fn expr_path_name(expr: &Expr) -> Option<String> {
    match expr {
        Expr::Path(path) => Some(path_to_string(&path.path)),
        Expr::Paren(ExprParen { expr, .. }) => expr_path_name(expr),
        Expr::Group(group) => expr_path_name(&group.expr),
        _ => None,
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
