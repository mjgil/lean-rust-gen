use lean_rust_core_generated::*;

use super::model::{
    as_binary_tree_u32, as_bool, as_bounded_proof, as_boxed_u32, as_char, as_choice, as_even_node,
    as_expr_u32, as_fn_u32, as_i32, as_i64, as_int, as_nat, as_nestedpayload_u32_string,
    as_odd_node, as_option_step, as_option_u32, as_option_u64, as_pairbox_u32_string,
    as_pairchoice_u32_string, as_point, as_prod_u32, as_result_u32_u32, as_step, as_string,
    as_tagged_u32, as_u32, as_u32_fn_case, as_u64, as_unit, as_vec_rosetree_u32, as_vec_u32,
    v_binary_tree_u32, v_bool, v_bounded_proof, v_boxed_u32, v_char, v_even_node, v_expr_u32,
    v_i32, v_i64, v_int, v_nat, v_nested_option_u32, v_nestedpayload_u32_string, v_odd_node,
    v_option_u32, v_ordering, v_pairbox_string_u32, v_pairbox_u32_string, v_pairchoice_u32_string,
    v_point, v_prod_u32, v_result_option_u32_u32, v_result_u32_option_u32, v_result_u32_string,
    v_result_u32_u32, v_rosetree_u32, v_step, v_string, v_tagged_u32, v_u32, v_u64, v_unit,
    v_vec_u32, Value,
};

pub fn dispatch_compiled_function(name: &str, args: &[Value]) -> Result<Value, String> {
    match name {
        "inhabited_default_u32" => Ok(v_u32(inhabited_default_u32(as_unit(&args[0])?))),
        "some_u32" => Ok(v_option_u32(some_u32(as_u32(&args[0])?))),
        "exact_int_mul" => Ok(v_int(exact_int_mul(as_int(&args[0])?, as_int(&args[1])?))),
        "result_ok_u32" => Ok(v_result_u32_u32(result_ok_u32(as_u32(&args[0])?))),
        "general_step_match_u32" => Ok(v_u32(general_step_match_u32(
            as_step(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "nested_payload_err_u32_string" => Ok(v_nestedpayload_u32_string(
            nested_payload_err_u32_string(as_string(&args[0])?, as_u32(&args[1])?),
        )),
        "list_append_u32" => Ok(v_vec_u32(list_append_u32(
            as_vec_u32(&args[0])?,
            as_vec_u32(&args[1])?,
        ))),
        "option_identity_u32" => Ok(v_option_u32(option_identity_u32(as_option_u32(&args[0])?))),
        "echo_string" => Ok(v_string(echo_string(as_string(&args[0])?))),
        "echo_char" => Ok(v_char(echo_char(as_char(&args[0])?))),
        "exact_nat_add" => Ok(v_nat(exact_nat_add(as_nat(&args[0])?, as_nat(&args[1])?))),
        "expr_lit_u32" => Ok(v_expr_u32(expr_lit_u32(as_u32(&args[0])?))),
        "tagged_present_u32" => Ok(v_tagged_u32(tagged_present_u32(as_u32(&args[0])?))),
        "unsupported_higher_order_u32" => Ok(v_u32(unsupported_higher_order_u32(
            as_fn_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "is_nonzero_u32" => Ok(v_bool(is_nonzero_u32(as_u32(&args[0])?))),
        "pair_choice_left_u32_string" => Ok(v_pairchoice_u32_string(pair_choice_left_u32_string(
            as_u32(&args[0])?,
        ))),
        "subtype_inc_u32" => Ok(v_u32(subtype_inc_u32(as_u32(&args[0])?))),
        "fin_val10_u32" => Ok(v_u32(fin_val10_u32(as_u32(&args[0])?))),
        "step_amount_plus_one_or" => Ok(v_u32(step_amount_plus_one_or(
            as_step(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "fin_checked10_u32" => Ok(v_option_u32(fin_checked10_u32(as_u32(&args[0])?))),
        "shift_point_x" => Ok(v_point(shift_point_x(
            as_point(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "array_fold_sum_u32" => Ok(v_u32(array_fold_sum_u32(as_vec_u32(&args[0])?))),
        "bool_match_u32" => Ok(v_u32(bool_match_u32(
            as_bool(&args[0])?,
            as_u32(&args[1])?,
            as_u32(&args[2])?,
        ))),
        "tree_node_u32" => Ok(v_binary_tree_u32(tree_node_u32(
            as_binary_tree_u32(&args[0])?,
            as_u32(&args[1])?,
            as_binary_tree_u32(&args[2])?,
        ))),
        "decidable_eq_u32" => Ok(v_bool(decidable_eq_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "generated_dict_beq_u32" => Ok(v_bool(generated_dict_beq_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "echo_list_u32" => Ok(v_vec_u32(echo_list_u32(as_vec_u32(&args[0])?))),
        "tree_leaf_u32" => Ok(v_binary_tree_u32(tree_leaf_u32(as_unit(&args[0])?))),
        "pair_box_swap_u32_string" => Ok(v_pairbox_string_u32(pair_box_swap_u32_string(
            as_pairbox_u32_string(&args[0])?,
        ))),
        "clamp_u32" => Ok(v_u32(clamp_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
            as_u32(&args[2])?,
        ))),
        "vector_map_inc3_u32" => Ok(v_vec_u32(vector_map_inc3_u32(as_vec_u32(&args[0])?))),
        "equality_cast_subtype_value_u32" => {
            Ok(v_u32(equality_cast_subtype_value_u32(as_u32(&args[0])?)))
        }
        "sigma_runtime_pair_echo_u32" => Ok(v_prod_u32(sigma_runtime_pair_echo_u32(as_prod_u32(
            &args[0],
        )?))),
        "sigma_runtime_pair_sum_u32" => {
            Ok(v_u32(sigma_runtime_pair_sum_u32(as_prod_u32(&args[0])?)))
        }
        "flag_carrier_true_roundtrip_u32" => {
            Ok(v_u32(flag_carrier_true_roundtrip_u32(as_u32(&args[0])?)))
        }
        "flag_carrier_false_value_u32" => {
            Ok(v_u32(flag_carrier_false_value_u32(as_u32(&args[0])?)))
        }
        "flag_carrier_match_invariant_u32" => Ok(v_u32(flag_carrier_match_invariant_u32(
            as_bool(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "nested_proof_wrapper_value_u32" => {
            Ok(v_u32(nested_proof_wrapper_value_u32(as_u32(&args[0])?)))
        }
        "pair_sum_match_u32" => Ok(v_u32(pair_sum_match_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "result_map_err_inc_u32" => Ok(v_result_u32_u32(result_map_err_inc_u32(
            as_result_u32_u32(&args[0])?,
        ))),
        "subtype_val_u32" => Ok(v_u32(subtype_val_u32(as_u32(&args[0])?))),
        "defun_apply_u32" => Ok(v_u32(defun_apply_u32(
            as_u32_fn_case(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "expr_add_u32" => Ok(v_expr_u32(expr_add_u32(
            as_expr_u32(&args[0])?,
            as_expr_u32(&args[1])?,
        ))),
        "expr_eval_u32" => Ok(v_u32(expr_eval_u32(as_expr_u32(&args[0])?))),
        "rose_branch_u32" => Ok(v_rosetree_u32(rose_branch_u32(
            as_u32(&args[0])?,
            as_vec_rosetree_u32(&args[1])?,
        ))),
        "even_terminal_u32" => Ok(v_even_node(even_terminal_u32(as_u32(&args[0])?))),
        "odd_terminal_u32" => Ok(v_odd_node(odd_terminal_u32(as_u32(&args[0])?))),
        "even_step_u32" => Ok(v_even_node(even_step_u32(
            as_u32(&args[0])?,
            as_odd_node(&args[1])?,
        ))),
        "odd_step_u32" => Ok(v_odd_node(odd_step_u32(
            as_u32(&args[0])?,
            as_even_node(&args[1])?,
        ))),
        "list_find_nonzero_u32" => Ok(v_option_u32(list_find_nonzero_u32(as_vec_u32(&args[0])?))),
        "list_head_or_zero_u32" => Ok(v_u32(list_head_or_zero_u32(as_vec_u32(&args[0])?))),
        "list_second_or_zero_u32" => Ok(v_u32(list_second_or_zero_u32(as_vec_u32(&args[0])?))),
        "list_reverse_first_or_u32" => Ok(v_u32(list_reverse_first_or_u32(
            as_vec_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "list_any_nonzero_u32" => Ok(v_bool(list_any_nonzero_u32(as_vec_u32(&args[0])?))),
        "exact_nat_mul" => Ok(v_nat(exact_nat_mul(as_nat(&args[0])?, as_nat(&args[1])?))),
        "step_jump" => Ok(v_step(step_jump(as_u32(&args[0])?))),
        "defun_map_selected_u32" => Ok(v_vec_u32(defun_map_selected_u32(
            as_bool(&args[0])?,
            as_vec_u32(&args[1])?,
        ))),
        "choose_by_enum" => Ok(v_u32(choose_by_enum(
            as_choice(&args[0])?,
            as_u32(&args[1])?,
            as_u32(&args[2])?,
        ))),
        "none_u32" => Ok(v_option_u32(none_u32(as_unit(&args[0])?))),
        "step_amount_or" => Ok(v_u32(step_amount_or(as_step(&args[0])?, as_u32(&args[1])?))),
        "closure_env_apply_add_delta_u32" => Ok(v_u32(closure_env_apply_add_delta_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "stored_closure_apply_u32" => Ok(v_u32(stored_closure_apply_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "stored_multi_closure_apply_u32" => Ok(v_u32(stored_multi_closure_apply_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
            as_u32(&args[2])?,
            as_u32(&args[3])?,
        ))),
        "returned_closure_apply_u32" => Ok(v_u32(returned_closure_apply_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "returned_multi_closure_apply_u32" => Ok(v_u32(returned_multi_closure_apply_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
            as_u32(&args[2])?,
            as_u32(&args[3])?,
        ))),
        "passed_closure_apply_u32" => Ok(v_u32(passed_closure_apply_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "passed_multi_closure_apply_u32" => Ok(v_u32(passed_multi_closure_apply_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
            as_u32(&args[2])?,
            as_u32(&args[3])?,
        ))),
        "option_bind_inc_u32" => Ok(v_option_u32(option_bind_inc_u32(as_option_u32(&args[0])?))),
        "ord_compare_u32" => Ok(v_ordering(ord_compare_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "generated_dict_compare_u32" => Ok(v_ordering(generated_dict_compare_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "defun_compose_inc_double_u32" => {
            Ok(v_u32(defun_compose_inc_double_u32(as_u32(&args[0])?)))
        }
        "pair_choice_default_u32_string" => Ok(v_u32(pair_choice_default_u32_string(
            as_pairchoice_u32_string(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "add_u32" => Ok(v_u32(add_u32(as_u32(&args[0])?, as_u32(&args[1])?))),
        "generated_dict_add_u32" => Ok(v_u32(generated_dict_add_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "checked_add_u32" => Ok(v_option_u32(checked_add_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "checked_sub_u32" => Ok(v_option_u32(checked_sub_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "checked_div_u32" => Ok(v_option_u32(checked_div_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "checked_mod_u32" => Ok(v_option_u32(checked_mod_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "repr_u32" => Ok(v_string(repr_u32(as_u32(&args[0])?))),
        "list_filter_nonzero_u32" => Ok(v_vec_u32(list_filter_nonzero_u32(as_vec_u32(&args[0])?))),
        "point_x" => Ok(v_u32(point_x(as_point(&args[0])?))),
        "nested_payload_value_or_u32_string" => Ok(v_u32(nested_payload_value_or_u32_string(
            as_nestedpayload_u32_string(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "add_u64" => Ok(v_u64(add_u64(as_u64(&args[0])?, as_u64(&args[1])?))),
        "boxed_u32" => Ok(v_boxed_u32(boxed_u32(as_u32(&args[0])?))),
        "defun_apply_add5_u32" => Ok(v_u32(defun_apply_add5_u32(as_u32(&args[0])?))),
        "echo_prod_u32" => Ok(v_prod_u32(echo_prod_u32(as_prod_u32(&args[0])?))),
        "option_getd_u32" => Ok(v_u32(option_getd_u32(
            as_option_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "array_get_opt_u32" => Ok(v_option_u32(array_get_opt_u32(
            as_vec_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "reader_add_env_u32" => Ok(v_u32(reader_add_env_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "bounded_proof_make_u32" => Ok(v_bounded_proof(bounded_proof_make_u32(as_u32(&args[0])?))),
        "bounded_proof_value_u32" => {
            Ok(v_u32(bounded_proof_value_u32(as_bounded_proof(&args[0])?)))
        }
        "bounded_bump_u32" => Ok(v_u32(bounded_bump_u32(as_u32(&args[0])?))),
        "unit_roundtrip" => {
            unit_roundtrip(as_unit(&args[0])?);
            Ok(v_unit(()))
        }
        "inc_u32" => Ok(v_u32(inc_u32(as_u32(&args[0])?))),
        "result_bind_inc_u32" => Ok(v_result_u32_u32(result_bind_inc_u32(as_result_u32_u32(
            &args[0],
        )?))),
        "make_point" => Ok(v_point(make_point(as_u32(&args[0])?, as_u32(&args[1])?))),
        "closure_apply_capture_u32" => Ok(v_u32(closure_apply_capture_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "subtype_roundtrip_u32" => Ok(v_u32(subtype_roundtrip_u32(as_u32(&args[0])?))),
        "tree_sum_u32" => Ok(v_u32(tree_sum_u32(as_binary_tree_u32(&args[0])?))),
        "tree_sum_worklist_u32" => Ok(v_u32(tree_sum_worklist_u32(as_binary_tree_u32(&args[0])?))),
        "fin_succ_checked10_u32" => Ok(v_option_u32(fin_succ_checked10_u32(as_u32(&args[0])?))),
        "result_err_some_u32" => Ok(v_result_u32_option_u32(result_err_some_u32(as_u32(
            &args[0],
        )?))),
        "list_map_add_capture_u32" => Ok(v_vec_u32(list_map_add_capture_u32(
            as_u32(&args[0])?,
            as_vec_u32(&args[1])?,
        ))),
        "general_bool_match_u32" => Ok(v_u32(general_bool_match_u32(
            as_bool(&args[0])?,
            as_u32(&args[1])?,
            as_u32(&args[2])?,
        ))),
        "option_map_inc_u32" => Ok(v_option_u32(option_map_inc_u32(as_option_u32(&args[0])?))),
        "pair_box_make_u32_string" => Ok(v_pairbox_u32_string(pair_box_make_u32_string(
            as_u32(&args[0])?,
            as_string(&args[1])?,
        ))),
        "echo_sum_u32" => Ok(v_result_u32_u32(echo_sum_u32(as_result_u32_u32(&args[0])?))),
        "to_string_u32" => Ok(v_string(to_string_u32(as_u32(&args[0])?))),
        "generated_dict_default_u32" => Ok(v_u32(generated_dict_default_u32(as_unit(&args[0])?))),
        "generated_dict_to_string_u32" => {
            Ok(v_string(generated_dict_to_string_u32(as_u32(&args[0])?)))
        }
        "echo_i64" => Ok(v_i64(echo_i64(as_i64(&args[0])?))),
        "step_stay" => Ok(v_step(step_stay(as_unit(&args[0])?))),
        "point_y" => Ok(v_u32(point_y(as_point(&args[0])?))),
        "general_option_match_u32" => Ok(v_u32(general_option_match_u32(
            as_option_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "echo_i32" => Ok(v_i32(echo_i32(as_i32(&args[0])?))),
        "result_map_ok_inc_u32" => Ok(v_result_u32_u32(result_map_ok_inc_u32(as_result_u32_u32(
            &args[0],
        )?))),
        "result_ok_none_u32" => Ok(v_result_option_u32_u32(result_ok_none_u32(as_unit(
            &args[0],
        )?))),
        "string_append_lean" => Ok(v_string(string_append_lean(
            as_string(&args[0])?,
            as_string(&args[1])?,
        ))),
        "string_length_chars_u32" => Ok(v_u32(string_length_chars_u32(as_string(&args[0])?))),
        "string_contains_char_lean" => Ok(v_bool(string_contains_char_lean(
            as_string(&args[0])?,
            as_char(&args[1])?,
        ))),
        "list_map_inc_u32" => Ok(v_vec_u32(list_map_inc_u32(as_vec_u32(&args[0])?))),
        "echo_array_u32" => Ok(v_vec_u32(echo_array_u32(as_vec_u32(&args[0])?))),
        "tagged_default_u32" => Ok(v_u32(tagged_default_u32(
            as_tagged_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "array_map_inc_u32" => Ok(v_vec_u32(array_map_inc_u32(as_vec_u32(&args[0])?))),
        "closure_env_map_add_delta_u32" => Ok(v_vec_u32(closure_env_map_add_delta_u32(
            as_u32(&args[0])?,
            as_vec_u32(&args[1])?,
        ))),
        "option_default_u32" => Ok(v_u32(option_default_u32(
            as_option_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "nested_none_u32" => Ok(v_nested_option_u32(nested_none_u32(as_unit(&args[0])?))),
        "array_push_u32" => Ok(v_vec_u32(array_push_u32(
            as_vec_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "max_u32" => Ok(v_u32(max_u32(as_u32(&args[0])?, as_u32(&args[1])?))),
        "mul_u32" => Ok(v_u32(mul_u32(as_u32(&args[0])?, as_u32(&args[1])?))),
        "saturating_add_u32" => Ok(v_u32(saturating_add_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "saturating_sub_u32" => Ok(v_u32(saturating_sub_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "preconditioned_div_u32" => Ok(v_result_u32_string(preconditioned_div_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "preconditioned_mod_u32" => Ok(v_result_u32_string(preconditioned_mod_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "checked_cast_u64_to_u32" => Ok(v_option_u32(checked_cast_u64_to_u32(as_u64(&args[0])?))),
        "vector_echo3_u32" => Ok(v_vec_u32(vector_echo3_u32(as_vec_u32(&args[0])?))),
        "result_err_u32" => Ok(v_result_u32_u32(result_err_u32(as_u32(&args[0])?))),
        "boxed_value_u32" => Ok(v_u32(boxed_value_u32(as_boxed_u32(&args[0])?))),
        "tail_sum_down_u32" => Ok(v_u32(tail_sum_down_u32(as_u32(&args[0])?))),
        "tagged_missing_u32" => Ok(v_tagged_u32(tagged_missing_u32(as_unit(&args[0])?))),
        "echo_u32" => Ok(v_u32(echo_u32(as_u32(&args[0])?))),
        "nat_sum_to_u32" => Ok(v_u32(nat_sum_to_u32(as_u32(&args[0])?))),
        "nat_pred_or_zero_u32" => Ok(v_u32(nat_pred_or_zero_u32(as_u32(&args[0])?))),
        "nat_two_step_or_zero_u32" => Ok(v_u32(nat_two_step_or_zero_u32(as_u32(&args[0])?))),
        "gcd_u32" => Ok(v_u32(gcd_u32(as_u32(&args[0])?, as_u32(&args[1])?))),
        "reverse_accum_u32" => Ok(v_vec_u32(reverse_accum_u32(
            as_vec_u32(&args[0])?,
            as_vec_u32(&args[1])?,
        ))),
        "mutual_even_u32" => Ok(v_bool(mutual_even_u32(as_u32(&args[0])?))),
        "mutual_odd_u32" => Ok(v_bool(mutual_odd_u32(as_u32(&args[0])?))),
        "proof_erased_u32" => Ok(v_u32(proof_erased_u32(as_u32(&args[0])?))),
        "tree_size_u32" => Ok(v_u32(tree_size_u32(as_binary_tree_u32(&args[0])?))),
        "list_fold_sum_u32" => Ok(v_u32(list_fold_sum_u32(as_vec_u32(&args[0])?))),
        "echo_u64" => Ok(v_u64(echo_u64(as_u64(&args[0])?))),
        "state_tick_u32" => Ok(v_prod_u32(state_tick_u32(as_u32(&args[0])?))),
        "list_foldr_sum_u32" => Ok(v_u32(list_foldr_sum_u32(as_vec_u32(&args[0])?))),
        "exact_int_add" => Ok(v_int(exact_int_add(as_int(&args[0])?, as_int(&args[1])?))),
        "list_length_u32" => Ok(v_u32(list_length_u32(as_vec_u32(&args[0])?))),
        "nested_payload_ok_u32_string" => Ok(v_nestedpayload_u32_string(
            nested_payload_ok_u32_string(as_u32(&args[0])?),
        )),
        "list_all_nonzero_u32" => Ok(v_bool(list_all_nonzero_u32(as_vec_u32(&args[0])?))),
        "identity_u64" => Ok(v_u64(identity_u64(as_u64(&args[0])?))),
        "choose_generic_u32" => Ok(v_u32(choose_generic_u32(
            as_bool(&args[0])?,
            as_u32(&args[1])?,
            as_u32(&args[2])?,
        ))),
        "option_default_u64" => Ok(v_u64(option_default_u64(
            as_option_u64(&args[0])?,
            as_u64(&args[1])?,
        ))),
        "generic_beq_u32" => Ok(v_bool(generic_beq_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "option_do_inc_u32" => Ok(v_option_u32(option_do_inc_u32(as_option_u32(&args[0])?))),
        "option_seq_right_u32" => Ok(v_option_u32(option_seq_right_u32(as_option_u32(&args[0])?))),
        "option_seq_left_u32" => Ok(v_option_u32(option_seq_left_u32(as_option_u32(&args[0])?))),
        "except_do_inc_u32" => Ok(v_result_u32_u32(except_do_inc_u32(as_result_u32_u32(
            &args[0],
        )?))),
        "except_seq_right_u32" => Ok(v_result_u32_u32(except_seq_right_u32(as_result_u32_u32(
            &args[0],
        )?))),
        "except_seq_left_u32" => Ok(v_result_u32_u32(except_seq_left_u32(as_result_u32_u32(
            &args[0],
        )?))),
        "generic_choose__point" => Ok(v_point(generic_choose__point(
            as_bool(&args[0])?,
            as_point(&args[1])?,
            as_point(&args[2])?,
        ))),
        "generic_identity__u32" => Ok(v_u32(generic_identity__u32(as_u32(&args[0])?))),
        "generic_option_default__step" => Ok(v_step(generic_option_default__step(
            as_option_step(&args[0])?,
            as_step(&args[1])?,
        ))),
        "helper_inc_fixed" => Ok(v_u32(helper_inc_fixed(as_u32(&args[0])?))),
        "auto_choose_point" => Ok(v_point(auto_choose_point(
            as_bool(&args[0])?,
            as_point(&args[1])?,
            as_point(&args[2])?,
        ))),
        "auto_identity_u32" => Ok(v_u32(auto_identity_u32(as_u32(&args[0])?))),
        "inc_twice_u32" => Ok(v_u32(inc_twice_u32(as_u32(&args[0])?))),
        "helper_chain_u32" => Ok(v_u32(helper_chain_u32(as_u32(&args[0])?))),
        "make_add_pair_u32" => Ok(v_u32(make_add_pair_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
            as_u32(&args[2])?,
            as_u32(&args[3])?,
        ))),
        "make_add_delta_u32" => Ok(v_u32(make_add_delta_u32(
            as_u32(&args[0])?,
            as_u32(&args[1])?,
        ))),
        "auto_option_default_step" => Ok(v_step(auto_option_default_step(
            as_option_step(&args[0])?,
            as_step(&args[1])?,
        ))),
        other => Err(format!(
            "missing compiled dispatch for target-validation function {other}"
        )),
    }
}
