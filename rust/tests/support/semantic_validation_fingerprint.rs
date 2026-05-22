use std::collections::BTreeSet;

use syn::{
    BinOp, Expr, ExprBlock, ExprCall, ExprField, ExprIf, ExprLit, ExprMatch, ExprMethodCall,
    ExprParen, ExprPath, ExprReference, ExprStruct, ExprUnary, Lit, Member, Pat,
};

use crate::{block_fingerprint, escape_snapshot_string, path_to_string};

pub(crate) fn expr_fingerprint(expr: &Expr, known_functions: &BTreeSet<String>) -> String {
    match expr {
        Expr::Paren(ExprParen { expr, .. }) => expr_fingerprint(expr, known_functions),
        Expr::Group(group) => expr_fingerprint(&group.expr, known_functions),
        Expr::Reference(ExprReference { expr, .. }) => expr_fingerprint(expr, known_functions),
        Expr::Path(path) => path_expr_fingerprint(path),
        Expr::Lit(lit) => literal_fingerprint(lit),
        Expr::Tuple(tuple) if tuple.elems.is_empty() => "unit".to_string(),
        Expr::Tuple(tuple) => format!(
            "tuple({})",
            tuple
                .elems
                .iter()
                .map(|expr| expr_fingerprint(expr, known_functions))
                .collect::<Vec<_>>()
                .join(",")
        ),
        Expr::Unary(unary) => unary_fingerprint(unary, known_functions),
        Expr::If(expr_if) => if_fingerprint(expr_if, known_functions),
        Expr::Binary(binary) => binary_fingerprint(binary, known_functions),
        Expr::MethodCall(method) => method_call_fingerprint(method, known_functions),
        Expr::Macro(item) => macro_fingerprint(item, known_functions),
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

fn unary_fingerprint(item: &ExprUnary, known_functions: &BTreeSet<String>) -> String {
    match &item.op {
        syn::UnOp::Deref(_) => format!("deref({})", expr_fingerprint(&item.expr, known_functions)),
        syn::UnOp::Not(_) => format!("not({})", expr_fingerprint(&item.expr, known_functions)),
        other => panic!("unsupported generated unary op during semantic validation: {other:?}"),
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
        "to_string" => {
            return format!(
                "to_string({})",
                expr_fingerprint(&item.receiver, known_functions)
            )
        }
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

fn macro_fingerprint(item: &syn::ExprMacro, known_functions: &BTreeSet<String>) -> String {
    format!(
        "repr({})",
        expr_fingerprint(
            &syn::parse_str::<Expr>(
                item.mac
                    .tokens
                    .to_string()
                    .split_once(',')
                    .expect("repr macro args")
                    .1
                    .trim()
            )
            .expect("generated repr arg"),
            known_functions
        )
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
            "Box::new" => {
                assert_eq!(args.len(), 1, "Box::new should receive one generated value");
                return format!("box({})", args[0]);
            }
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
        Pat::Ident(ident) if ident.ident == "None" => PatternSummary::None,
        other => {
            panic!("unsupported generated match pattern during semantic validation: {other:?}")
        }
    }
}

pub(crate) fn pattern_binder(pat: &Pat) -> String {
    match pat {
        Pat::Ident(ident) => ident.ident.to_string(),
        Pat::Type(pat) => pattern_binder(&pat.pat),
        other => panic!("unsupported generated payload binder pattern: {other:?}"),
    }
}

pub(crate) fn expr_path_name(expr: &Expr) -> Option<String> {
    match expr {
        Expr::Path(path) => Some(path_to_string(&path.path)),
        Expr::Paren(ExprParen { expr, .. }) => expr_path_name(expr),
        Expr::Group(group) => expr_path_name(&group.expr),
        _ => None,
    }
}
