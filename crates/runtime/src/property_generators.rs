use std::rc::Rc;

use crate::{
    closure_return_add_delta, dictionary_add_u32, rc_tree_leaf_u32, rc_tree_node_u32, AddDictU32,
    RcTreeU32,
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PropertyRng {
    state: u64,
}

impl PropertyRng {
    pub fn seeded(seed: u64) -> Self {
        Self {
            state: seed ^ 0x9E37_79B9_7F4A_7C15,
        }
    }

    fn next_u64(&mut self) -> u64 {
        self.state ^= self.state << 7;
        self.state ^= self.state >> 9;
        self.state ^= self.state << 8;
        self.state
    }

    pub fn next_u32(&mut self) -> u32 {
        self.next_u64() as u32
    }

    pub fn next_bool(&mut self) -> bool {
        self.next_u64() & 1 == 0
    }

    pub fn choose(&mut self, bound: usize) -> usize {
        if bound == 0 {
            0
        } else {
            (self.next_u64() as usize) % bound
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RuntimeValueCase {
    BaseScalar(u32),
    Container(Vec<u32>),
    RecursiveTree(Rc<RcTreeU32>),
    ClosureDictionary { delta: u32, lhs: u32, rhs: u32 },
}

fn generate_recursive_tree(rng: &mut PropertyRng, depth: usize) -> Rc<RcTreeU32> {
    if depth == 0 || rng.next_bool() {
        rc_tree_leaf_u32()
    } else {
        let left = generate_recursive_tree(rng, depth - 1);
        let right = generate_recursive_tree(rng, depth - 1);
        rc_tree_node_u32(left, rng.next_u32(), right)
    }
}

pub fn generate_runtime_value_cases(seed: u64, count: usize) -> Vec<RuntimeValueCase> {
    let mut rng = PropertyRng::seeded(seed);
    let mut out = Vec::with_capacity(count);
    for idx in 0..count {
        out.push(match idx % 4 {
            0 => RuntimeValueCase::BaseScalar(rng.next_u32()),
            1 => {
                let len = 1 + rng.choose(4);
                let values = (0..len).map(|_| rng.next_u32()).collect();
                RuntimeValueCase::Container(values)
            }
            2 => RuntimeValueCase::RecursiveTree(generate_recursive_tree(&mut rng, 3)),
            _ => RuntimeValueCase::ClosureDictionary {
                delta: rng.next_u32(),
                lhs: rng.next_u32(),
                rhs: rng.next_u32(),
            },
        });
    }
    out
}

pub fn shrink_runtime_value_case(case: &RuntimeValueCase) -> Vec<RuntimeValueCase> {
    match case {
        RuntimeValueCase::BaseScalar(value) => {
            if *value <= 1 {
                Vec::new()
            } else {
                vec![
                    RuntimeValueCase::BaseScalar(0),
                    RuntimeValueCase::BaseScalar(1),
                    RuntimeValueCase::BaseScalar(value / 2),
                    RuntimeValueCase::BaseScalar(value - 1),
                ]
            }
        }
        RuntimeValueCase::Container(values) => {
            if values.is_empty() {
                Vec::new()
            } else {
                let mut out = vec![RuntimeValueCase::Container(Vec::new())];
                out.push(RuntimeValueCase::Container(
                    values[..values.len() / 2].to_vec(),
                ));
                let mut head = values.clone();
                head[0] /= 2;
                out.push(RuntimeValueCase::Container(head));
                out
            }
        }
        RuntimeValueCase::RecursiveTree(tree) => match tree.as_ref() {
            RcTreeU32::Leaf => Vec::new(),
            RcTreeU32::Node(left, _, right) => vec![
                RuntimeValueCase::RecursiveTree(rc_tree_leaf_u32()),
                RuntimeValueCase::RecursiveTree(left.clone()),
                RuntimeValueCase::RecursiveTree(right.clone()),
            ],
        },
        RuntimeValueCase::ClosureDictionary { delta, lhs, rhs } => {
            let mut out = Vec::new();
            if *delta > 0 {
                out.push(RuntimeValueCase::ClosureDictionary {
                    delta: delta / 2,
                    lhs: *lhs,
                    rhs: *rhs,
                });
            }
            if *lhs > 0 || *rhs > 0 {
                out.push(RuntimeValueCase::ClosureDictionary {
                    delta: *delta,
                    lhs: lhs / 2,
                    rhs: rhs / 2,
                });
            }
            out
        }
    }
}

pub fn minimize_runtime_value_case<F>(
    mut current: RuntimeValueCase,
    mut predicate: F,
) -> RuntimeValueCase
where
    F: FnMut(&RuntimeValueCase) -> bool,
{
    loop {
        let mut next = None;
        for candidate in shrink_runtime_value_case(&current) {
            if predicate(&candidate) {
                next = Some(candidate);
                break;
            }
        }
        match next {
            Some(candidate) => current = candidate,
            None => return current,
        }
    }
}

pub fn runtime_case_depth(case: &RuntimeValueCase) -> usize {
    match case {
        RuntimeValueCase::BaseScalar(_) => 0,
        RuntimeValueCase::Container(values) => values.len(),
        RuntimeValueCase::RecursiveTree(tree) => match tree.as_ref() {
            RcTreeU32::Leaf => 0,
            RcTreeU32::Node(left, _, right) => {
                1 + runtime_case_depth(&RuntimeValueCase::RecursiveTree(left.clone())).max(
                    runtime_case_depth(&RuntimeValueCase::RecursiveTree(right.clone())),
                )
            }
        },
        RuntimeValueCase::ClosureDictionary { .. } => 1,
    }
}

pub fn runtime_case_exercises_first_order_helpers(
    case: &RuntimeValueCase,
    dict: AddDictU32,
) -> bool {
    match case {
        RuntimeValueCase::BaseScalar(value) => {
            closure_return_add_delta(1).apply(*value) == value.wrapping_add(1)
        }
        RuntimeValueCase::Container(values) => {
            values
                .iter()
                .copied()
                .fold(0u32, |acc, value| dictionary_add_u32(dict, acc, value))
                == values.iter().copied().fold(0u32, u32::wrapping_add)
        }
        RuntimeValueCase::RecursiveTree(tree) => {
            runtime_case_depth(case) <= 3
                && matches!(tree.as_ref(), RcTreeU32::Leaf | RcTreeU32::Node(_, _, _))
        }
        RuntimeValueCase::ClosureDictionary { delta, lhs, rhs } => {
            closure_return_add_delta(*delta).apply(*lhs) == lhs.wrapping_add(*delta)
                && dictionary_add_u32(dict, *lhs, *rhs) == lhs.wrapping_add(*rhs)
        }
    }
}
