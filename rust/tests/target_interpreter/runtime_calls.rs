use lean_rust_core_generated::recursion_helpers::tree_sum_worklist_u32 as helper_tree_sum_worklist_u32;
use lean_rust_core_generated::runtime::{
    array_get_u32, dictionary_add_u32, dictionary_beq_u32, dictionary_compare_u32,
    dictionary_default_u32, dictionary_to_string_u32, list_head_clone, list_head_or_default_u32,
    list_prepend_u32, list_reverse_u32, list_second_or_default_u32, list_tail_clone, string_append,
    string_contains_char, string_length_chars, u32_checked_add, u32_checked_div, u32_checked_mod,
    u32_checked_sub, u32_preconditioned_div, u32_preconditioned_mod, u32_saturating_add,
    u32_saturating_sub, u64_to_u32_checked, ADD_U32, BEQ_U32, DEFAULT_U32, ORD_U32, TO_STRING_U32,
};
use lean_rust_core_generated::Ordering;

use super::model::{as_binary_tree_u32, as_char, as_string, as_u32, as_u64, as_vec_u32, Value};

pub fn eval_runtime_call(name: &str, values: &[Value]) -> Option<Result<Value, String>> {
    let result = match name {
        "__runtime_u32_checked_add" => Ok(Value::OptionU32(u32_checked_add(
            as_u32(&values[0]).ok()?,
            as_u32(&values[1]).ok()?,
        ))),
        "__runtime_u32_checked_sub" => Ok(Value::OptionU32(u32_checked_sub(
            as_u32(&values[0]).ok()?,
            as_u32(&values[1]).ok()?,
        ))),
        "__runtime_u32_checked_div" => Ok(Value::OptionU32(u32_checked_div(
            as_u32(&values[0]).ok()?,
            as_u32(&values[1]).ok()?,
        ))),
        "__runtime_u32_checked_mod" => Ok(Value::OptionU32(u32_checked_mod(
            as_u32(&values[0]).ok()?,
            as_u32(&values[1]).ok()?,
        ))),
        "__runtime_u32_saturating_add" => Ok(Value::U32(u32_saturating_add(
            as_u32(&values[0]).ok()?,
            as_u32(&values[1]).ok()?,
        ))),
        "__runtime_u32_saturating_sub" => Ok(Value::U32(u32_saturating_sub(
            as_u32(&values[0]).ok()?,
            as_u32(&values[1]).ok()?,
        ))),
        "__runtime_u32_preconditioned_div" => Ok(Value::ResultU32String(
            u32_preconditioned_div(as_u32(&values[0]).ok()?, as_u32(&values[1]).ok()?)
                .map_err(String::from),
        )),
        "__runtime_u32_preconditioned_mod" => Ok(Value::ResultU32String(
            u32_preconditioned_mod(as_u32(&values[0]).ok()?, as_u32(&values[1]).ok()?)
                .map_err(String::from),
        )),
        "__runtime_u64_to_u32_checked" => Ok(Value::OptionU32(u64_to_u32_checked(
            as_u64(&values[0]).ok()?,
        ))),
        "__runtime_list_head_clone" => match &values[0] {
            Value::VecU32(values) => Ok(Value::OptionU32(list_head_clone(values))),
            other => Err(format!(
                "unsupported __runtime_list_head_clone target {other:?}"
            )),
        },
        "__runtime_list_head_or_default_u32" => Ok(Value::U32(list_head_or_default_u32(
            &as_vec_u32(&values[0]).ok()?,
            as_u32(&values[1]).ok()?,
        ))),
        "__runtime_list_second_or_default_u32" => Ok(Value::U32(list_second_or_default_u32(
            &as_vec_u32(&values[0]).ok()?,
            as_u32(&values[1]).ok()?,
        ))),
        "__runtime_list_tail_clone" => match &values[0] {
            Value::VecU32(values) => Ok(Value::VecU32(list_tail_clone(values))),
            Value::VecRoseTreeU32(values) => Ok(Value::VecRoseTreeU32(list_tail_clone(values))),
            other => Err(format!(
                "unsupported __runtime_list_tail_clone target {other:?}"
            )),
        },
        "__runtime_list_prepend_u32" => Ok(Value::VecU32(list_prepend_u32(
            as_u32(&values[0]).ok()?,
            as_vec_u32(&values[1]).ok()?,
        ))),
        "__runtime_list_reverse_u32" => Ok(Value::VecU32(list_reverse_u32(
            as_vec_u32(&values[0]).ok()?,
        ))),
        "__runtime_tree_sum_worklist_u32" => Ok(Value::U32(helper_tree_sum_worklist_u32(
            as_binary_tree_u32(&values[0]).ok()?,
        ))),
        "__runtime_array_get_u32" => Ok(Value::OptionU32(array_get_u32(
            &as_vec_u32(&values[0]).ok()?,
            as_u32(&values[1]).ok()? as usize,
        ))),
        "__runtime_string_append" => Ok(Value::String(string_append(
            as_string(&values[0]).ok()?,
            &as_string(&values[1]).ok()?,
        ))),
        "__runtime_string_length_chars" => Ok(Value::U32(string_length_chars(
            &as_string(&values[0]).ok()?,
        ) as u32)),
        "__runtime_string_contains_char" => Ok(Value::Bool(string_contains_char(
            &as_string(&values[0]).ok()?,
            as_char(&values[1]).ok()?,
        ))),
        "__runtime_dictionary_beq_u32_const" => Ok(Value::Bool(dictionary_beq_u32(
            BEQ_U32,
            as_u32(&values[0]).ok()?,
            as_u32(&values[1]).ok()?,
        ))),
        "__runtime_dictionary_compare_u32_const" => {
            let ordering = match dictionary_compare_u32(
                ORD_U32,
                as_u32(&values[0]).ok()?,
                as_u32(&values[1]).ok()?,
            ) {
                std::cmp::Ordering::Less => Ordering::Lt,
                std::cmp::Ordering::Equal => Ordering::Eq,
                std::cmp::Ordering::Greater => Ordering::Gt,
            };
            Ok(Value::Ordering(ordering))
        }
        "__runtime_dictionary_add_u32_const" => Ok(Value::U32(dictionary_add_u32(
            ADD_U32,
            as_u32(&values[0]).ok()?,
            as_u32(&values[1]).ok()?,
        ))),
        "__runtime_dictionary_default_u32_const" => {
            Ok(Value::U32(dictionary_default_u32(DEFAULT_U32)))
        }
        "__runtime_dictionary_to_string_u32_const" => Ok(Value::String(dictionary_to_string_u32(
            TO_STRING_U32,
            as_u32(&values[0]).ok()?,
        ))),
        _ => return None,
    };
    Some(result)
}
