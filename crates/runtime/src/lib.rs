#![forbid(unsafe_code)]
//! Safe runtime helpers shared by generated Lean→Rust output.
//!
//! The generated crate may reexport this crate, but the helpers remain separate
//! so they can be tested and documented without mixing runtime policy into
//! `generated.rs`.

use std::cmp::Ordering;

use num_bigint::{BigInt, BigUint};

pub fn exact_nat_add(a: BigUint, b: BigUint) -> BigUint {
    a + b
}

pub fn exact_nat_mul(a: BigUint, b: BigUint) -> BigUint {
    a * b
}

pub fn exact_int_add(a: BigInt, b: BigInt) -> BigInt {
    a + b
}

pub fn u32_checked_add(a: u32, b: u32) -> Option<u32> {
    a.checked_add(b)
}

pub fn u32_checked_sub(a: u32, b: u32) -> Option<u32> {
    a.checked_sub(b)
}

pub fn u32_checked_mul(a: u32, b: u32) -> Option<u32> {
    a.checked_mul(b)
}

pub fn u32_saturating_add(a: u32, b: u32) -> u32 {
    a.saturating_add(b)
}

pub fn u32_saturating_sub(a: u32, b: u32) -> u32 {
    a.saturating_sub(b)
}

pub fn u32_preconditioned_div(a: u32, b: u32) -> Result<u32, &'static str> {
    if b == 0 {
        Err("division-by-zero")
    } else {
        Ok(a / b)
    }
}

pub fn u32_preconditioned_mod(a: u32, b: u32) -> Result<u32, &'static str> {
    if b == 0 {
        Err("modulus-by-zero")
    } else {
        Ok(a % b)
    }
}

pub fn nat_to_u32_checked(n: u128) -> Option<u32> {
    u32::try_from(n).ok()
}

pub fn list_reverse_u32(mut xs: Vec<u32>) -> Vec<u32> {
    xs.reverse();
    xs
}

pub fn list_zip_u32(xs: Vec<u32>, ys: Vec<u32>) -> Vec<(u32, u32)> {
    xs.into_iter().zip(ys).collect()
}

pub fn array_get_u32(xs: &[u32], index: usize) -> Option<u32> {
    xs.get(index).copied()
}

pub fn array_set_u32(mut xs: Vec<u32>, index: usize, value: u32) -> Option<Vec<u32>> {
    if let Some(slot) = xs.get_mut(index) {
        *slot = value;
        Some(xs)
    } else {
        None
    }
}

pub fn string_length_chars(s: &str) -> usize {
    s.chars().count()
}

pub fn string_contains(s: &str, needle: &str) -> bool {
    s.contains(needle)
}

pub fn string_append(mut left: String, right: &str) -> String {
    left.push_str(right);
    left
}

#[derive(Clone, Copy)]
pub struct BeqDictU32 {
    pub beq: fn(u32, u32) -> bool,
}

#[derive(Clone, Copy)]
pub struct OrdDictU32 {
    pub compare: fn(u32, u32) -> Ordering,
}

pub const BEQ_U32: BeqDictU32 = BeqDictU32 { beq: |a, b| a == b };

pub const ORD_U32: OrdDictU32 = OrdDictU32 {
    compare: |a, b| a.cmp(&b),
};

pub fn dictionary_beq_u32(dict: BeqDictU32, a: u32, b: u32) -> bool {
    (dict.beq)(a, b)
}

pub fn dictionary_compare_u32(dict: OrdDictU32, a: u32, b: u32) -> Ordering {
    (dict.compare)(a, b)
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum U32ClosureObject {
    Id,
    Inc,
    AddDelta(u32),
    Compose(Box<U32ClosureObject>, Box<U32ClosureObject>),
}

impl U32ClosureObject {
    pub fn apply(&self, value: u32) -> u32 {
        match self {
            Self::Id => value,
            Self::Inc => value.wrapping_add(1),
            Self::AddDelta(delta) => value.wrapping_add(*delta),
            Self::Compose(first, second) => second.apply(first.apply(value)),
        }
    }
}

pub fn closure_return_add_delta(delta: u32) -> U32ClosureObject {
    U32ClosureObject::AddDelta(delta)
}

pub fn closure_map_u32(f: &U32ClosureObject, xs: Vec<u32>) -> Vec<u32> {
    xs.into_iter().map(|x| f.apply(x)).collect()
}

pub fn option_do_inc_runtime(input: Option<u32>) -> Option<u32> {
    let value = input?;
    Some(value.wrapping_add(1))
}

pub fn result_do_inc_runtime(input: Result<u32, u32>) -> Result<u32, u32> {
    let value = input?;
    Ok(value.wrapping_add(1))
}

pub fn state_tick_runtime(state: u32) -> (u32, u32) {
    (state, state.wrapping_add(1))
}

pub fn reader_add_env_runtime(env: u32, value: u32) -> u32 {
    env.wrapping_add(value)
}

#[cfg(test)]
mod tests {
    use super::*;
    use num_bigint::{BigInt, BigUint};

    #[test]
    fn numeric_edge_cases_are_documented_by_tests() {
        assert_eq!(u32_checked_add(u32::MAX, 1), None);
        assert_eq!(u32_checked_sub(0, 1), None);
        assert_eq!(u32_saturating_add(u32::MAX, 1), u32::MAX);
        assert_eq!(u32_saturating_sub(0, 1), 0);
        assert_eq!(u32_preconditioned_div(8, 2), Ok(4));
        assert_eq!(u32_preconditioned_div(8, 0), Err("division-by-zero"));
        assert_eq!(
            exact_nat_add(BigUint::from(40u32), BigUint::from(2u32)),
            BigUint::from(42u32)
        );
        assert_eq!(
            exact_int_add(BigInt::from(-40i32), BigInt::from(2i32)),
            BigInt::from(-38i32)
        );
    }

    #[test]
    fn containers_strings_dictionaries_and_closures_are_tested() {
        assert_eq!(list_reverse_u32(vec![1, 2, 3]), vec![3, 2, 1]);
        assert_eq!(list_zip_u32(vec![1, 2], vec![3, 4]), vec![(1, 3), (2, 4)]);
        assert_eq!(array_get_u32(&[1, 2, 3], 1), Some(2));
        assert_eq!(array_set_u32(vec![1, 2], 1, 9), Some(vec![1, 9]));
        assert_eq!(string_length_chars("hé"), 2);
        assert!(string_contains("lean-rust-core", "rust"));
        assert!(dictionary_beq_u32(BEQ_U32, 7, 7));
        assert_eq!(dictionary_compare_u32(ORD_U32, 1, 2), Ordering::Less);
        let f = closure_return_add_delta(5);
        assert_eq!(f.apply(37), 42);
        assert_eq!(closure_map_u32(&f, vec![0, 37]), vec![5, 42]);
    }
}
