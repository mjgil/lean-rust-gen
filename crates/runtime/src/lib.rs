#![forbid(unsafe_code)]
//! Safe runtime helpers shared by generated Lean→Rust output.
//!
//! The generated crate may reexport this crate, but the helpers remain separate
//! so numeric modes, ownership choices, recursive layouts, Std lowerings,
//! typeclass dictionaries, and closure objects can be tested independently.

use std::cmp::Ordering;
use std::rc::Rc;

use num_bigint::{BigInt, BigUint};

pub fn exact_nat_add(a: BigUint, b: BigUint) -> BigUint {
    a + b
}

pub fn exact_nat_mul(a: BigUint, b: BigUint) -> BigUint {
    a * b
}

pub fn exact_nat_sub_checked(a: BigUint, b: BigUint) -> Option<BigUint> {
    if a >= b {
        Some(a - b)
    } else {
        None
    }
}

pub fn exact_int_add(a: BigInt, b: BigInt) -> BigInt {
    a + b
}

pub fn exact_int_mul(a: BigInt, b: BigInt) -> BigInt {
    a * b
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

pub fn u32_checked_div(a: u32, b: u32) -> Option<u32> {
    a.checked_div(b)
}

pub fn u32_checked_mod(a: u32, b: u32) -> Option<u32> {
    a.checked_rem(b)
}

pub fn u64_checked_add(a: u64, b: u64) -> Option<u64> {
    a.checked_add(b)
}

pub fn u64_checked_sub(a: u64, b: u64) -> Option<u64> {
    a.checked_sub(b)
}

pub fn u64_checked_mul(a: u64, b: u64) -> Option<u64> {
    a.checked_mul(b)
}

pub fn i32_checked_add(a: i32, b: i32) -> Option<i32> {
    a.checked_add(b)
}

pub fn i32_checked_sub(a: i32, b: i32) -> Option<i32> {
    a.checked_sub(b)
}

pub fn i32_checked_mul(a: i32, b: i32) -> Option<i32> {
    a.checked_mul(b)
}

pub fn i64_checked_add(a: i64, b: i64) -> Option<i64> {
    a.checked_add(b)
}

pub fn i64_checked_sub(a: i64, b: i64) -> Option<i64> {
    a.checked_sub(b)
}

pub fn i64_checked_mul(a: i64, b: i64) -> Option<i64> {
    a.checked_mul(b)
}

pub fn u32_saturating_add(a: u32, b: u32) -> u32 {
    a.saturating_add(b)
}

pub fn u32_saturating_sub(a: u32, b: u32) -> u32 {
    a.saturating_sub(b)
}

pub fn u32_saturating_mul(a: u32, b: u32) -> u32 {
    a.saturating_mul(b)
}

pub fn u64_saturating_add(a: u64, b: u64) -> u64 {
    a.saturating_add(b)
}

pub fn u64_saturating_sub(a: u64, b: u64) -> u64 {
    a.saturating_sub(b)
}

pub fn i32_saturating_add(a: i32, b: i32) -> i32 {
    a.saturating_add(b)
}

pub fn i32_saturating_sub(a: i32, b: i32) -> i32 {
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

pub fn int_to_i32_checked(n: i128) -> Option<i32> {
    i32::try_from(n).ok()
}

pub fn int_to_i64_checked(n: i128) -> Option<i64> {
    i64::try_from(n).ok()
}

pub fn u64_to_u32_checked(n: u64) -> Option<u32> {
    u32::try_from(n).ok()
}

pub fn list_append_u32(mut xs: Vec<u32>, ys: Vec<u32>) -> Vec<u32> {
    xs.extend(ys);
    xs
}

pub fn list_find_nonzero_u32(xs: &[u32]) -> Option<u32> {
    xs.iter().copied().find(|value| *value != 0)
}

pub fn list_reverse_u32(mut xs: Vec<u32>) -> Vec<u32> {
    xs.reverse();
    xs
}

pub fn list_zip_u32(xs: Vec<u32>, ys: Vec<u32>) -> Vec<(u32, u32)> {
    xs.into_iter().zip(ys).collect()
}

pub fn list_partition_nonzero_u32(xs: Vec<u32>) -> (Vec<u32>, Vec<u32>) {
    xs.into_iter().partition(|value| *value != 0)
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

pub fn borrowed_vec_len_u32(xs: &[u32]) -> usize {
    xs.len()
}

pub fn borrowed_string_is_empty(s: &str) -> bool {
    s.is_empty()
}

pub fn clone_vec_for_shared_use(xs: &[u32]) -> Vec<u32> {
    xs.to_vec()
}

pub fn clone_then_append_u32(xs: &[u32], value: u32) -> Vec<u32> {
    let mut out = xs.to_vec();
    out.push(value);
    out
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

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RcTreeU32 {
    Leaf,
    Node(Rc<RcTreeU32>, u32, Rc<RcTreeU32>),
}

pub fn rc_tree_leaf_u32() -> Rc<RcTreeU32> {
    Rc::new(RcTreeU32::Leaf)
}

pub fn rc_tree_node_u32(left: Rc<RcTreeU32>, value: u32, right: Rc<RcTreeU32>) -> Rc<RcTreeU32> {
    Rc::new(RcTreeU32::Node(left, value, right))
}

pub fn rc_tree_sum_u32(tree: &Rc<RcTreeU32>) -> u32 {
    match tree.as_ref() {
        RcTreeU32::Leaf => 0,
        RcTreeU32::Node(left, value, right) => rc_tree_sum_u32(left)
            .wrapping_add(*value)
            .wrapping_add(rc_tree_sum_u32(right)),
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ArenaNodeId(pub usize);

#[derive(Clone, Debug, PartialEq, Eq)]
enum ArenaTreeNodeU32 {
    Leaf,
    Node {
        left: ArenaNodeId,
        value: u32,
        right: ArenaNodeId,
    },
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct ArenaTreeU32 {
    nodes: Vec<ArenaTreeNodeU32>,
}

impl ArenaTreeU32 {
    pub fn new() -> Self {
        Self { nodes: Vec::new() }
    }

    pub fn leaf(&mut self) -> ArenaNodeId {
        let id = ArenaNodeId(self.nodes.len());
        self.nodes.push(ArenaTreeNodeU32::Leaf);
        id
    }

    pub fn node(
        &mut self,
        left: ArenaNodeId,
        value: u32,
        right: ArenaNodeId,
    ) -> Option<ArenaNodeId> {
        if left.0 >= self.nodes.len() || right.0 >= self.nodes.len() {
            return None;
        }
        let id = ArenaNodeId(self.nodes.len());
        self.nodes
            .push(ArenaTreeNodeU32::Node { left, value, right });
        Some(id)
    }

    pub fn sum(&self, root: ArenaNodeId) -> Option<u32> {
        match self.nodes.get(root.0)? {
            ArenaTreeNodeU32::Leaf => Some(0),
            ArenaTreeNodeU32::Node { left, value, right } => Some(
                self.sum(*left)?
                    .wrapping_add(*value)
                    .wrapping_add(self.sum(*right)?),
            ),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use num_bigint::{BigInt, BigUint};

    #[test]
    fn numeric_edge_cases_are_documented_by_tests() {
        assert_eq!(u32_checked_add(u32::MAX, 1), None);
        assert_eq!(u32_checked_sub(0, 1), None);
        assert_eq!(u32_checked_mul(u32::MAX, 2), None);
        assert_eq!(u32_checked_div(8, 0), None);
        assert_eq!(u32_checked_mod(8, 0), None);
        assert_eq!(u32_saturating_add(u32::MAX, 1), u32::MAX);
        assert_eq!(u32_saturating_sub(0, 1), 0);
        assert_eq!(u32_saturating_mul(u32::MAX, 2), u32::MAX);
        assert_eq!(u32_preconditioned_div(8, 2), Ok(4));
        assert_eq!(u32_preconditioned_div(8, 0), Err("division-by-zero"));
        assert_eq!(u32_preconditioned_mod(8, 0), Err("modulus-by-zero"));
        assert_eq!(u64_checked_add(u64::MAX, 1), None);
        assert_eq!(i32_checked_add(i32::MAX, 1), None);
        assert_eq!(i64_checked_mul(i64::MAX, 2), None);
        assert_eq!(nat_to_u32_checked(u128::from(u32::MAX)), Some(u32::MAX));
        assert_eq!(nat_to_u32_checked(u128::from(u32::MAX) + 1), None);
        assert_eq!(int_to_i32_checked(i128::from(i32::MIN)), Some(i32::MIN));
        assert_eq!(u64_to_u32_checked(u64::from(u32::MAX) + 1), None);
        assert_eq!(
            exact_nat_add(BigUint::from(40u32), BigUint::from(2u32)),
            BigUint::from(42u32)
        );
        assert_eq!(
            exact_int_add(BigInt::from(-40i32), BigInt::from(2i32)),
            BigInt::from(-38i32)
        );
        assert_eq!(
            exact_int_mul(BigInt::from(-7i32), BigInt::from(6i32)),
            BigInt::from(-42i32)
        );
    }

    #[test]
    fn containers_strings_dictionaries_and_closures_are_tested() {
        assert_eq!(list_append_u32(vec![1, 2], vec![3]), vec![1, 2, 3]);
        assert_eq!(list_find_nonzero_u32(&[0, 0, 42]), Some(42));
        assert_eq!(list_reverse_u32(vec![1, 2, 3]), vec![3, 2, 1]);
        assert_eq!(list_zip_u32(vec![1, 2], vec![3, 4]), vec![(1, 3), (2, 4)]);
        assert_eq!(
            list_partition_nonzero_u32(vec![0, 1, 0, 2]),
            (vec![1, 2], vec![0, 0])
        );
        assert_eq!(array_get_u32(&[1, 2, 3], 1), Some(2));
        assert_eq!(array_set_u32(vec![1, 2], 1, 9), Some(vec![1, 9]));
        assert_eq!(string_length_chars("hé"), 2);
        assert!(string_contains("lean-rust-core", "rust"));
        assert_eq!(string_append(String::from("lean"), "-rust"), "lean-rust");
        assert_eq!(borrowed_vec_len_u32(&[1, 2, 3]), 3);
        assert!(borrowed_string_is_empty(""));
        assert_eq!(clone_vec_for_shared_use(&[1, 2]), vec![1, 2]);
        assert_eq!(clone_then_append_u32(&[1, 2], 3), vec![1, 2, 3]);
        assert!(dictionary_beq_u32(BEQ_U32, 7, 7));
        assert_eq!(dictionary_compare_u32(ORD_U32, 1, 2), Ordering::Less);
        let f = closure_return_add_delta(5);
        assert_eq!(f.apply(37), 42);
        assert_eq!(closure_map_u32(&f, vec![0, 37]), vec![5, 42]);
    }

    #[test]
    fn recursive_layouts_and_ownership_helpers_are_tested() {
        let leaf = rc_tree_leaf_u32();
        let tree = rc_tree_node_u32(leaf.clone(), 42, leaf);
        assert_eq!(rc_tree_sum_u32(&tree), 42);

        let mut arena = ArenaTreeU32::new();
        let left = arena.leaf();
        let right = arena.leaf();
        let root = arena.node(left, 42, right).unwrap();
        assert_eq!(arena.sum(root), Some(42));
        assert_eq!(arena.node(ArenaNodeId(999), 1, root), None);
        assert_eq!(arena.sum(ArenaNodeId(999)), None);
    }
}
