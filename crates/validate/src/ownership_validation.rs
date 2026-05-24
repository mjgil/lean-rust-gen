use syn::{
    BinOp, Expr, ExprBinary, ExprReference, FieldPat, Fields, File, FnArg, GenericArgument,
    ImplItem, Item, ItemEnum, ItemFn, ItemImpl, ItemStruct, Lifetime, Member, Pat, PathArguments,
    ReturnType, Signature, Stmt, Type, TypeParamBound, Variant,
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OwnershipValidation {
    pub approved_reference_exprs: usize,
    pub violations: Vec<String>,
}

impl OwnershipValidation {
    fn push_violation(&mut self, message: impl Into<String>) {
        self.violations.push(message.into());
    }
}

pub fn validate_generated_ownership(source: &str) -> Result<OwnershipValidation, syn::Error> {
    let file = syn::parse_file(source)?;
    Ok(validate_generated_ownership_file(&file))
}

pub fn validate_generated_ownership_file(file: &File) -> OwnershipValidation {
    let mut validation = OwnershipValidation {
        approved_reference_exprs: 0,
        violations: Vec::new(),
    };
    scan_file(file, &mut validation);
    validation
}

fn scan_file(file: &File, validation: &mut OwnershipValidation) {
    for item in &file.items {
        scan_item(item, validation);
    }
}

fn scan_item(item: &Item, validation: &mut OwnershipValidation) {
    match item {
        Item::Fn(item) => scan_item_fn(item, validation),
        Item::Struct(item) => scan_item_struct(item, validation),
        Item::Enum(item) => scan_item_enum(item, validation),
        Item::Impl(item) => scan_item_impl(item, validation),
        _ => {}
    }
}

fn scan_item_fn(item: &ItemFn, validation: &mut OwnershipValidation) {
    scan_signature(&item.sig, validation);
    scan_block(&item.block.stmts, validation);
}

fn scan_item_struct(item: &ItemStruct, validation: &mut OwnershipValidation) {
    scan_lifetimes_in_generics(&item.generics.lifetimes().collect::<Vec<_>>(), validation);
    scan_fields(&item.fields, validation);
}

fn scan_item_enum(item: &ItemEnum, validation: &mut OwnershipValidation) {
    scan_lifetimes_in_generics(&item.generics.lifetimes().collect::<Vec<_>>(), validation);
    for variant in &item.variants {
        scan_variant(variant, validation);
    }
}

fn scan_item_impl(item: &ItemImpl, validation: &mut OwnershipValidation) {
    if let Some((_, path, _)) = &item.trait_ {
        scan_path(path, validation);
    }
    scan_type(&item.self_ty, validation);
    for impl_item in &item.items {
        if let ImplItem::Fn(function) = impl_item {
            scan_signature(&function.sig, validation);
            scan_block(&function.block.stmts, validation);
        }
    }
}

fn scan_signature(sig: &Signature, validation: &mut OwnershipValidation) {
    scan_lifetimes_in_generics(&sig.generics.lifetimes().collect::<Vec<_>>(), validation);
    for input in &sig.inputs {
        if let FnArg::Typed(arg) = input {
            scan_type(&arg.ty, validation);
            scan_pat(&arg.pat, validation);
        }
    }
    if let ReturnType::Type(_, ty) = &sig.output {
        scan_type(ty, validation);
    }
}

fn scan_variant(variant: &Variant, validation: &mut OwnershipValidation) {
    scan_fields(&variant.fields, validation);
}

fn scan_fields(fields: &Fields, validation: &mut OwnershipValidation) {
    match fields {
        Fields::Named(named) => {
            for field in &named.named {
                scan_type(&field.ty, validation);
            }
        }
        Fields::Unnamed(unnamed) => {
            for field in &unnamed.unnamed {
                scan_type(&field.ty, validation);
            }
        }
        Fields::Unit => {}
    }
}

fn scan_block(stmts: &[Stmt], validation: &mut OwnershipValidation) {
    for stmt in stmts {
        match stmt {
            Stmt::Local(local) => {
                scan_pat(&local.pat, validation);
                if let Some(init) = &local.init {
                    scan_expr(&init.expr, false, validation);
                    if let Some((_, diverge)) = &init.diverge {
                        scan_expr(diverge, false, validation);
                    }
                }
            }
            Stmt::Item(item) => scan_item(item, validation),
            Stmt::Expr(expr, _) => scan_expr(expr, false, validation),
            Stmt::Macro(_) => {}
        }
    }
}

fn scan_pat(pat: &Pat, validation: &mut OwnershipValidation) {
    match pat {
        Pat::Ident(_)
        | Pat::Lit(_)
        | Pat::Path(_)
        | Pat::Range(_)
        | Pat::Rest(_)
        | Pat::Wild(_) => {}
        Pat::Or(pat_or) => {
            for case in &pat_or.cases {
                scan_pat(case, validation);
            }
        }
        Pat::Paren(inner) => scan_pat(&inner.pat, validation),
        Pat::Reference(reference) => {
            validation.push_violation("generated Rust must not pattern-bind by reference");
            scan_pat(&reference.pat, validation);
        }
        Pat::Slice(slice) => {
            for elem in &slice.elems {
                scan_pat(elem, validation);
            }
        }
        Pat::Struct(pattern) => {
            scan_path(&pattern.path, validation);
            for field in &pattern.fields {
                scan_field_pat(field, validation);
            }
        }
        Pat::Tuple(tuple) => {
            for elem in &tuple.elems {
                scan_pat(elem, validation);
            }
        }
        Pat::TupleStruct(pattern) => {
            scan_path(&pattern.path, validation);
            for elem in &pattern.elems {
                scan_pat(elem, validation);
            }
        }
        Pat::Type(pattern) => {
            scan_pat(&pattern.pat, validation);
            scan_type(&pattern.ty, validation);
        }
        _ => {}
    }
}

fn scan_field_pat(field: &FieldPat, validation: &mut OwnershipValidation) {
    scan_member(&field.member, validation);
    scan_pat(&field.pat, validation);
}

fn scan_member(member: &Member, validation: &mut OwnershipValidation) {
    if let Member::Named(ident) = member {
        if ident.to_string().starts_with('\'') {
            validation.push_violation(format!(
                "generated Rust must not synthesize lifetime-looking member {}",
                ident
            ));
        }
    }
}

fn scan_type(ty: &Type, validation: &mut OwnershipValidation) {
    match ty {
        Type::Array(array) => {
            scan_expr(&array.len, false, validation);
            scan_type(&array.elem, validation);
        }
        Type::BareFn(function) => {
            if function.lifetimes.is_some() {
                validation.push_violation(
                    "generated Rust must not emit explicit lifetimes on bare function types",
                );
            }
            for input in &function.inputs {
                scan_type(&input.ty, validation);
            }
            if let ReturnType::Type(_, ty) = &function.output {
                scan_type(ty, validation);
            }
        }
        Type::Group(group) => scan_type(&group.elem, validation),
        Type::ImplTrait(impl_trait) => {
            for bound in &impl_trait.bounds {
                scan_type_param_bound(bound, validation);
            }
        }
        Type::Macro(_) => {}
        Type::Paren(paren) => scan_type(&paren.elem, validation),
        Type::Path(path) => scan_path(&path.path, validation),
        Type::Ptr(pointer) => {
            validation.push_violation("generated Rust must not emit raw pointer types");
            scan_type(&pointer.elem, validation);
        }
        Type::Reference(reference) => {
            let _ = ty;
            validation.push_violation("generated Rust must not emit reference types");
            if let Some(lifetime) = &reference.lifetime {
                scan_lifetime(lifetime, validation);
            }
            scan_type(&reference.elem, validation);
        }
        Type::Slice(slice) => scan_type(&slice.elem, validation),
        Type::TraitObject(object) => {
            for bound in &object.bounds {
                scan_type_param_bound(bound, validation);
            }
        }
        Type::Tuple(tuple) => {
            for elem in &tuple.elems {
                scan_type(elem, validation);
            }
        }
        _ => {}
    }
}

fn scan_path(path: &syn::Path, validation: &mut OwnershipValidation) {
    for segment in &path.segments {
        match &segment.arguments {
            PathArguments::None => {}
            PathArguments::AngleBracketed(arguments) => {
                for argument in &arguments.args {
                    match argument {
                        GenericArgument::Lifetime(lifetime) => scan_lifetime(lifetime, validation),
                        GenericArgument::Type(ty) => scan_type(ty, validation),
                        GenericArgument::Const(expr) => scan_expr(expr, false, validation),
                        GenericArgument::AssocType(binding) => scan_type(&binding.ty, validation),
                        GenericArgument::AssocConst(binding) => {
                            scan_expr(&binding.value, false, validation)
                        }
                        GenericArgument::Constraint(constraint) => {
                            for bound in &constraint.bounds {
                                scan_type_param_bound(bound, validation);
                            }
                        }
                        _ => {}
                    }
                }
            }
            PathArguments::Parenthesized(arguments) => {
                for input in &arguments.inputs {
                    scan_type(input, validation);
                }
                if let ReturnType::Type(_, ty) = &arguments.output {
                    scan_type(ty, validation);
                }
            }
        }
    }
}

fn scan_type_param_bound(bound: &TypeParamBound, validation: &mut OwnershipValidation) {
    match bound {
        TypeParamBound::Trait(trait_bound) => {
            if trait_bound.lifetimes.is_some() {
                validation.push_violation(
                    "generated Rust must not emit explicit lifetimes in trait bounds",
                );
            }
            scan_path(&trait_bound.path, validation);
        }
        TypeParamBound::Lifetime(lifetime) => scan_lifetime(lifetime, validation),
        _ => {}
    }
}

fn scan_lifetimes_in_generics(
    lifetimes: &[&syn::LifetimeParam],
    validation: &mut OwnershipValidation,
) {
    for lifetime in lifetimes {
        scan_lifetime(&lifetime.lifetime, validation);
        for bound in &lifetime.bounds {
            scan_lifetime(bound, validation);
        }
    }
}

fn scan_lifetime(lifetime: &Lifetime, validation: &mut OwnershipValidation) {
    validation.push_violation(format!(
        "generated Rust must not emit explicit lifetimes; found {}",
        lifetime.ident
    ));
}

fn scan_expr(
    expr: &Expr,
    allow_temporary_shared_borrow: bool,
    validation: &mut OwnershipValidation,
) {
    match expr {
        Expr::Array(array) => {
            for elem in &array.elems {
                scan_expr(elem, false, validation);
            }
        }
        Expr::Assign(assign) => {
            scan_expr(&assign.left, false, validation);
            scan_expr(&assign.right, false, validation);
        }
        Expr::Async(async_expr) => scan_block(&async_expr.block.stmts, validation),
        Expr::Binary(binary) => scan_expr_binary(binary, validation),
        Expr::Block(block) => scan_block(&block.block.stmts, validation),
        Expr::Break(expr_break) => {
            if let Some(expr) = &expr_break.expr {
                scan_expr(expr, false, validation);
            }
        }
        Expr::Call(call) => {
            scan_expr(&call.func, false, validation);
            for (index, arg) in call.args.iter().enumerate() {
                scan_expr(
                    arg,
                    allow_runtime_helper_borrow(&call.func, index),
                    validation,
                );
            }
        }
        Expr::Cast(cast) => {
            scan_expr(&cast.expr, false, validation);
            scan_type(&cast.ty, validation);
        }
        Expr::Closure(closure) => scan_expr(&closure.body, false, validation),
        Expr::Field(field) => scan_expr(&field.base, false, validation),
        Expr::ForLoop(for_loop) => {
            scan_pat(&for_loop.pat, validation);
            scan_expr(&for_loop.expr, false, validation);
            scan_block(&for_loop.body.stmts, validation);
        }
        Expr::If(expr_if) => {
            scan_expr(&expr_if.cond, false, validation);
            scan_block(&expr_if.then_branch.stmts, validation);
            if let Some((_, else_expr)) = &expr_if.else_branch {
                scan_expr(else_expr, false, validation);
            }
        }
        Expr::Index(index) => {
            scan_expr(&index.expr, false, validation);
            scan_expr(&index.index, false, validation);
        }
        Expr::Let(expr_let) => {
            scan_pat(&expr_let.pat, validation);
            scan_expr(&expr_let.expr, false, validation);
        }
        Expr::Loop(expr_loop) => scan_block(&expr_loop.body.stmts, validation),
        Expr::Macro(_) => {}
        Expr::Match(expr_match) => {
            scan_expr(&expr_match.expr, false, validation);
            for arm in &expr_match.arms {
                scan_pat(&arm.pat, validation);
                if let Some((_, guard)) = &arm.guard {
                    scan_expr(guard, false, validation);
                }
                scan_expr(&arm.body, false, validation);
            }
        }
        Expr::MethodCall(call) => {
            scan_expr(&call.receiver, false, validation);
            for arg in &call.args {
                scan_expr(arg, false, validation);
            }
        }
        Expr::Paren(paren) => scan_expr(&paren.expr, allow_temporary_shared_borrow, validation),
        Expr::Path(_) | Expr::Lit(_) | Expr::Continue(_) => {}
        Expr::Range(range) => {
            if let Some(from) = &range.start {
                scan_expr(from, false, validation);
            }
            if let Some(to) = &range.end {
                scan_expr(to, false, validation);
            }
        }
        Expr::Reference(reference) => {
            scan_expr_reference(reference, allow_temporary_shared_borrow, validation);
        }
        Expr::Repeat(repeat) => {
            scan_expr(&repeat.expr, false, validation);
            scan_expr(&repeat.len, false, validation);
        }
        Expr::Return(expr_return) => {
            if let Some(expr) = &expr_return.expr {
                scan_expr(expr, false, validation);
            }
        }
        Expr::Struct(expr_struct) => {
            scan_path(&expr_struct.path, validation);
            for field in &expr_struct.fields {
                scan_member(&field.member, validation);
                scan_expr(&field.expr, false, validation);
            }
            if let Some(rest) = &expr_struct.rest {
                scan_expr(rest, false, validation);
            }
        }
        Expr::Try(expr_try) => scan_expr(&expr_try.expr, false, validation),
        Expr::Tuple(tuple) => {
            for elem in &tuple.elems {
                scan_expr(elem, false, validation);
            }
        }
        Expr::Unary(unary) => scan_expr(&unary.expr, false, validation),
        Expr::While(expr_while) => {
            scan_expr(&expr_while.cond, false, validation);
            scan_block(&expr_while.body.stmts, validation);
        }
        _ => {}
    }
}

fn scan_expr_binary(binary: &ExprBinary, validation: &mut OwnershipValidation) {
    let allow_temporary_shared_borrow = matches!(
        binary.op,
        BinOp::Add(_) | BinOp::Sub(_) | BinOp::Mul(_) | BinOp::Lt(_)
    );
    scan_expr(&binary.left, allow_temporary_shared_borrow, validation);
    scan_expr(&binary.right, allow_temporary_shared_borrow, validation);
}

fn allow_runtime_helper_borrow(func: &Expr, index: usize) -> bool {
    match runtime_helper_name(func).as_deref() {
        Some("array_get_u32") => index == 0,
        Some("string_append") => index == 1,
        Some("string_length_chars") => index == 0,
        Some("string_contains_char") => index == 0,
        _ => false,
    }
}

fn runtime_helper_name(func: &Expr) -> Option<String> {
    let Expr::Path(path) = func else {
        return None;
    };
    path.path
        .segments
        .last()
        .map(|segment| segment.ident.to_string())
}

fn scan_expr_reference(
    reference: &ExprReference,
    allow_temporary_shared_borrow: bool,
    validation: &mut OwnershipValidation,
) {
    if reference.mutability.is_some() {
        validation.push_violation("generated Rust must not emit mutable references");
    }
    if !allow_temporary_shared_borrow {
        validation.push_violation("generated Rust emitted an unapproved reference expression");
    } else if reference.mutability.is_none() {
        validation.approved_reference_exprs += 1;
    }
    scan_expr(&reference.expr, false, validation);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_exact_integer_operand_borrows_and_rejects_reference_types() {
        let accepted = validate_generated_ownership(
            "pub fn exact_nat_add(a: num_bigint::BigUint, b: num_bigint::BigUint) -> num_bigint::BigUint { (&(a)) + (&(b)) }",
        )
        .unwrap();
        assert_eq!(accepted.approved_reference_exprs, 2);
        assert!(accepted.violations.is_empty());

        let rejected =
            validate_generated_ownership("pub fn bad<'a>(xs: &'a [u32]) -> &'a [u32] { xs }")
                .unwrap();
        assert!(!rejected.violations.is_empty());
        assert!(rejected
            .violations
            .iter()
            .any(|violation| violation.contains("explicit lifetimes")));
        assert!(rejected
            .violations
            .iter()
            .any(|violation| violation.contains("reference types")));
    }

    #[test]
    fn rejects_reference_expressions_outside_exact_integer_operands() {
        let rejected =
            validate_generated_ownership("pub fn bad(a: u32) -> u32 { let borrow = &(a); a }")
                .unwrap();
        assert!(rejected
            .violations
            .iter()
            .any(|violation| violation.contains("unapproved reference expression")));
    }
}
