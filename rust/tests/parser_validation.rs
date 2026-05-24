use std::collections::BTreeSet;

use lean_rust_core_validate::validate_generated_ownership;
use syn::{
    visit::{self, Visit},
    ExprMacro, ExprUnsafe, FnArg, Item, ItemEnum, ItemFn, ItemForeignMod, ItemStruct,
};

const GENERATED_SOURCE: &str = include_str!("../src/generated.rs");

fn parse_generated() -> syn::File {
    syn::parse_file(GENERATED_SOURCE).expect("generated Rust should parse as a complete Rust file")
}

#[test]
fn generated_rust_parses_with_syn() {
    parse_generated();
}

#[test]
fn parser_validates_generated_top_level_subset() {
    let file = parse_generated();
    let mut functions = BTreeSet::new();
    let mut types = BTreeSet::new();

    for item in &file.items {
        match item {
            Item::Struct(item) => {
                validate_struct(item);
                assert!(
                    types.insert(item.ident.to_string()),
                    "duplicate generated type {}",
                    item.ident
                );
            }
            Item::Enum(item) => {
                validate_enum(item);
                assert!(
                    types.insert(item.ident.to_string()),
                    "duplicate generated type {}",
                    item.ident
                );
            }
            Item::Fn(item) => {
                validate_fn(item);
                assert!(
                    functions.insert(item.sig.ident.to_string()),
                    "duplicate generated function {}",
                    item.sig.ident
                );
            }
            other => panic!("generated Rust used unsupported top-level item: {other:?}"),
        }
    }

    for required in [
        "Point",
        "BoundedProof",
        "BoxedU32",
        "AddDeltaU32Env",
        "Choice",
        "TaggedU32",
        "Step",
        "U32FnCase",
        "BinaryTreeU32",
        "ExprU32",
        "RoseTreeU32",
        "EvenNode",
        "OddNode",
        "Ordering",
    ] {
        assert!(
            types.contains(required),
            "missing generated type {required}"
        );
    }

    for required in [
        "clamp_u32",
        "add_u32",
        "echo_string",
        "echo_list_u32",
        "echo_array_u32",
        "list_map_inc_u32",
        "list_fold_sum_u32",
        "echo_prod_u32",
        "echo_sum_u32",
        "inc_twice_u32",
        "helper_chain_u32",
        "proof_erased_u32",
        "bounded_proof_make_u32",
        "bounded_proof_value_u32",
        "equality_cast_subtype_value_u32",
        "sigma_runtime_pair_echo_u32",
        "sigma_runtime_pair_sum_u32",
        "flag_carrier_true_roundtrip_u32",
        "flag_carrier_false_value_u32",
        "flag_carrier_match_invariant_u32",
        "nested_proof_wrapper_value_u32",
        "subtype_val_u32",
        "subtype_inc_u32",
        "subtype_roundtrip_u32",
        "fin_checked10_u32",
        "fin_succ_checked10_u32",
        "vector_map_inc3_u32",
        "boxed_u32",
        "boxed_value_u32",
        "tagged_default_u32",
        "unsupported_higher_order_u32",
        "step_amount_or",
        "step_amount_plus_one_or",
        "general_bool_match_u32",
        "general_option_match_u32",
        "general_step_match_u32",
        "pair_sum_match_u32",
        "list_length_u32",
        "tail_sum_down_u32",
        "option_default_u64",
        "generic_beq_u32",
        "generic_identity__u32",
        "generic_choose__point",
        "generic_option_default__step",
        "helper_inc_fixed",
        "exact_nat_add",
        "exact_nat_mul",
        "exact_int_add",
        "exact_int_mul",
        "list_append_u32",
        "list_find_nonzero_u32",
        "array_push_u32",
        "option_getd_u32",
        "option_do_inc_u32",
        "option_seq_right_u32",
        "option_seq_left_u32",
        "except_do_inc_u32",
        "except_seq_right_u32",
        "except_seq_left_u32",
        "reader_do_add_u32",
        "reader_seq_right_u32",
        "reader_seq_left_u32",
        "state_do_tick_u32",
        "state_seq_right_u32",
        "state_seq_left_u32",
        "except_state_do_u32",
        "except_state_seq_right_u32",
        "except_state_seq_left_u32",
        "result_map_err_inc_u32",
        "reader_add_env_u32",
        "state_tick_u32",
        "generated_dict_beq_u32",
        "generated_dict_compare_u32",
        "generated_dict_add_u32",
        "generated_dict_default_u32",
        "generated_dict_to_string_u32",
        "stored_closure_apply_u32",
        "stored_multi_closure_apply_u32",
        "returned_closure_apply_u32",
        "returned_multi_closure_apply_u32",
        "passed_closure_apply_u32",
        "passed_multi_closure_apply_u32",
        "closure_env_apply_add_delta_u32",
        "closure_env_map_add_delta_u32",
        "defun_apply_u32",
        "defun_compose_inc_double_u32",
        "defun_apply_add5_u32",
        "defun_map_selected_u32",
        "tree_leaf_u32",
        "tree_node_u32",
        "tree_size_u32",
        "tree_sum_u32",
        "expr_lit_u32",
        "expr_add_u32",
        "expr_eval_u32",
        "rose_branch_u32",
        "even_terminal_u32",
        "odd_terminal_u32",
        "even_step_u32",
        "odd_step_u32",
        "auto_identity_u32",
        "auto_choose_point",
        "auto_option_default_step",
    ] {
        assert!(
            functions.contains(required),
            "missing generated function {required}"
        );
    }
}

#[test]
fn parser_rejects_raw_boundary_or_panic_constructs() {
    let file = parse_generated();
    let mut visitor = BannedConstructVisitor::default();
    visitor.visit_file(&file);

    assert!(
        visitor.violations.is_empty(),
        "generated Rust left the approved safe subset: {:?}",
        visitor.violations
    );
}

#[test]
fn parser_validates_generated_ownership_policy() {
    let validation =
        validate_generated_ownership(GENERATED_SOURCE).expect("generated Rust should parse");
    assert_eq!(validation.approved_reference_exprs, 16);
    assert!(
        validation.violations.is_empty(),
        "generated Rust violated ownership/reference policy: {:?}",
        validation.violations
    );
}

fn validate_struct(item: &ItemStruct) {
    assert!(
        item.generics.params.is_empty(),
        "generated structs must be monomorphic"
    );
    match &item.fields {
        syn::Fields::Named(fields) => {
            let mut seen = BTreeSet::new();
            for field in &fields.named {
                let ident = field.ident.as_ref().expect("named field").to_string();
                assert!(
                    seen.insert(ident.clone()),
                    "duplicate generated struct field {ident}"
                );
            }
        }
        _ => panic!("generated structs must use named fields"),
    }
}

fn validate_enum(item: &ItemEnum) {
    assert!(
        item.generics.params.is_empty(),
        "generated enums must be monomorphic"
    );
    let mut seen = BTreeSet::new();
    for variant in &item.variants {
        assert!(
            seen.insert(variant.ident.to_string()),
            "duplicate generated enum variant {}",
            variant.ident
        );
        match &variant.fields {
            syn::Fields::Unit | syn::Fields::Unnamed(_) => {}
            syn::Fields::Named(_) => {
                panic!("generated enum variants must be unit or tuple variants")
            }
        }
    }
}

fn validate_fn(item: &ItemFn) {
    assert!(
        item.sig.unsafety.is_none(),
        "generated functions must be safe"
    );
    assert!(
        item.sig.abi.is_none(),
        "generated functions must not declare raw ABI boundaries"
    );
    assert!(
        item.sig.generics.params.is_empty(),
        "generated functions must be monomorphic"
    );

    let mut args = BTreeSet::new();
    for input in &item.sig.inputs {
        match input {
            FnArg::Typed(arg) => match arg.pat.as_ref() {
                syn::Pat::Ident(pat) => {
                    let ident = pat.ident.to_string();
                    assert!(
                        args.insert(ident.clone()),
                        "duplicate generated function argument {ident}"
                    );
                }
                other => panic!("generated function argument used unsupported pattern: {other:?}"),
            },
            FnArg::Receiver(_) => panic!("generated functions must not be methods"),
        }
    }
}

#[derive(Default)]
struct BannedConstructVisitor {
    violations: Vec<String>,
}

impl<'ast> Visit<'ast> for BannedConstructVisitor {
    fn visit_item_foreign_mod(&mut self, _: &'ast ItemForeignMod) {
        self.violations.push("extern block".to_string());
    }

    fn visit_expr_unsafe(&mut self, _: &'ast ExprUnsafe) {
        self.violations.push("unsafe block".to_string());
    }

    fn visit_expr_macro(&mut self, node: &'ast ExprMacro) {
        if let Some(segment) = node.mac.path.segments.last() {
            let name = segment.ident.to_string();
            if matches!(name.as_str(), "panic" | "todo" | "unimplemented") {
                self.violations.push(format!("banned macro {name}!"));
            }
        }
        visit::visit_expr_macro(self, node);
    }
}
