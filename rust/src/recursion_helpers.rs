use crate::BinaryTreeU32;

pub fn tree_sum_worklist_u32(tree: BinaryTreeU32) -> u32 {
    let mut acc = 0u32;
    let mut worklist = vec![tree];
    while let Some(node) = worklist.pop() {
        match node {
            BinaryTreeU32::Leaf => {}
            BinaryTreeU32::Node(left, value, right) => {
                acc = acc.wrapping_add(value);
                worklist.push(*right);
                worklist.push(*left);
            }
        }
    }
    acc
}

#[cfg(test)]
mod tests {
    use super::tree_sum_worklist_u32;
    use crate::{tree_leaf_u32, tree_node_u32};

    #[test]
    fn explicit_stack_tree_sum_matches_recursive_example() {
        let tree = tree_node_u32(
            tree_node_u32(tree_leaf_u32(()), 1, tree_leaf_u32(())),
            40,
            tree_node_u32(tree_leaf_u32(()), 1, tree_leaf_u32(())),
        );
        assert_eq!(tree_sum_worklist_u32(tree), 42);
    }
}
