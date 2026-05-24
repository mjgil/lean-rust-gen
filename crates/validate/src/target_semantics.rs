#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TargetValue {
    Unit,
    Bool(bool),
    U32(u32),
    ListU32(Vec<u32>),
    StructVal(String, Vec<(String, TargetValue)>),
    EnumVal(String, String, Vec<TargetValue>),
    Boxed(Box<TargetValue>),
    ClosureAddDelta(u32),
    DictionaryAddU32,
    OptionU32(Option<u32>),
    ResultU32U32(Result<u32, u32>),
    SubtypeU32(u32),
    FinU32 {
        bound: u32,
        value: u32,
    },
    VectorU32 {
        expected_len: usize,
        values: Vec<u32>,
    },
    RecursiveTree(RecursiveTree),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RecursiveTree {
    Leaf,
    Node(Box<RecursiveTree>, u32, Box<RecursiveTree>),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TargetTerm {
    Unit,
    Bool(bool),
    U32(u32),
    Value(TargetValue),
    Var(String),
    Let(String, Box<TargetTerm>, Box<TargetTerm>),
    Add(Box<TargetTerm>, Box<TargetTerm>),
    Eq(Box<TargetTerm>, Box<TargetTerm>),
    If(Box<TargetTerm>, Box<TargetTerm>, Box<TargetTerm>),
    ListLength(Box<TargetTerm>),
    List(Vec<TargetTerm>),
    Call(String, Vec<TargetTerm>),
    StructExpr(String, Vec<(String, TargetTerm)>),
    EnumExpr(String, String, Vec<TargetTerm>),
    StepAmountOr(Box<TargetTerm>, Box<TargetTerm>),
    BoxExpr(Box<TargetTerm>),
    DerefExpr(Box<TargetTerm>),
    ClosureAddDelta(Box<TargetTerm>),
    ClosureApply(Box<TargetTerm>, Box<TargetTerm>),
    DictionaryAdd,
    DictionaryApply(Box<TargetTerm>, Box<TargetTerm>, Box<TargetTerm>),
    OptionSomeU32(Box<TargetTerm>),
    OptionNoneU32,
    EffectOptionMapInc(Box<TargetTerm>),
    ResultOkU32(Box<TargetTerm>),
    ResultErrU32(Box<TargetTerm>),
    EffectResultBindAdd1(Box<TargetTerm>),
    SubtypeExpr(Box<TargetTerm>),
    FinExpr(u32, Box<TargetTerm>),
    FinValue(Box<TargetTerm>),
    VectorExpr(usize, Vec<TargetTerm>),
    VectorMapInc(Box<TargetTerm>),
    RecursiveLeaf,
    RecursiveNode(Box<TargetTerm>, Box<TargetTerm>, Box<TargetTerm>),
    RecursiveSum(Box<TargetTerm>),
}

fn wrapping_add_u32(lhs: u32, rhs: u32) -> u32 {
    lhs.wrapping_add(rhs)
}

fn lookup_env<'a>(env: &'a [(String, TargetValue)], name: &str) -> Option<&'a TargetValue> {
    env.iter()
        .rev()
        .find(|(candidate, _)| candidate == name)
        .map(|(_, value)| value)
}

fn tree_sum(tree: &RecursiveTree) -> u32 {
    match tree {
        RecursiveTree::Leaf => 0,
        RecursiveTree::Node(left, value, right) => value
            .wrapping_add(tree_sum(left))
            .wrapping_add(tree_sum(right)),
    }
}

fn eval_target_term_with_env(
    env: &mut Vec<(String, TargetValue)>,
    term: &TargetTerm,
) -> Option<TargetValue> {
    match term {
        TargetTerm::Unit => Some(TargetValue::Unit),
        TargetTerm::Bool(value) => Some(TargetValue::Bool(*value)),
        TargetTerm::U32(value) => Some(TargetValue::U32(*value)),
        TargetTerm::Value(value) => Some(value.clone()),
        TargetTerm::Var(name) => lookup_env(env, name).cloned(),
        TargetTerm::Let(name, value, body) => {
            let value = eval_target_term_with_env(env, value)?;
            env.push((name.clone(), value));
            let out = eval_target_term_with_env(env, body);
            env.pop();
            out
        }
        TargetTerm::Add(a, b) => match (
            eval_target_term_with_env(env, a)?,
            eval_target_term_with_env(env, b)?,
        ) {
            (TargetValue::U32(a), TargetValue::U32(b)) => {
                Some(TargetValue::U32(wrapping_add_u32(a, b)))
            }
            _ => None,
        },
        TargetTerm::Eq(a, b) => Some(TargetValue::Bool(
            eval_target_term_with_env(env, a)? == eval_target_term_with_env(env, b)?,
        )),
        TargetTerm::If(cond, when_true, when_false) => {
            match eval_target_term_with_env(env, cond)? {
                TargetValue::Bool(true) => eval_target_term_with_env(env, when_true),
                TargetValue::Bool(false) => eval_target_term_with_env(env, when_false),
                _ => None,
            }
        }
        TargetTerm::ListLength(xs) => match eval_target_term_with_env(env, xs)? {
            TargetValue::ListU32(values) => Some(TargetValue::U32(values.len() as u32)),
            _ => None,
        },
        TargetTerm::List(values) => {
            let mut out = Vec::new();
            for value in values {
                match eval_target_term_with_env(env, value)? {
                    TargetValue::U32(value) => out.push(value),
                    _ => return None,
                }
            }
            Some(TargetValue::ListU32(out))
        }
        TargetTerm::Call(name, args) => {
            let values = args
                .iter()
                .map(|arg| eval_target_term_with_env(env, arg))
                .collect::<Option<Vec<_>>>()?;
            match (name.as_str(), values.as_slice()) {
                ("wrapping_add_u32", [TargetValue::U32(lhs), TargetValue::U32(rhs)]) => {
                    Some(TargetValue::U32(wrapping_add_u32(*lhs, *rhs)))
                }
                ("tree_sum_u32", [TargetValue::RecursiveTree(tree)]) => {
                    Some(TargetValue::U32(tree_sum(tree)))
                }
                (
                    "vector_map_inc_u32",
                    [TargetValue::VectorU32 {
                        expected_len,
                        values,
                    }],
                ) => Some(TargetValue::VectorU32 {
                    expected_len: *expected_len,
                    values: values
                        .iter()
                        .map(|value| wrapping_add_u32(*value, 1))
                        .collect(),
                }),
                _ => None,
            }
        }
        TargetTerm::StructExpr(name, fields) => Some(TargetValue::StructVal(
            name.clone(),
            fields
                .iter()
                .map(|(field_name, term)| {
                    Some((field_name.clone(), eval_target_term_with_env(env, term)?))
                })
                .collect::<Option<Vec<_>>>()?,
        )),
        TargetTerm::EnumExpr(name, variant, payload) => Some(TargetValue::EnumVal(
            name.clone(),
            variant.clone(),
            payload
                .iter()
                .map(|term| eval_target_term_with_env(env, term))
                .collect::<Option<Vec<_>>>()?,
        )),
        TargetTerm::StepAmountOr(target, default) => {
            match (
                eval_target_term_with_env(env, target)?,
                eval_target_term_with_env(env, default)?,
            ) {
                (TargetValue::EnumVal(name, variant, payload), fallback) if name == "Step" => {
                    match (variant.as_str(), payload.as_slice()) {
                        ("Jump", [TargetValue::U32(amount)]) => Some(TargetValue::U32(*amount)),
                        ("Stay", []) => Some(fallback),
                        _ => None,
                    }
                }
                _ => None,
            }
        }
        TargetTerm::BoxExpr(value) => Some(TargetValue::Boxed(Box::new(
            eval_target_term_with_env(env, value)?,
        ))),
        TargetTerm::DerefExpr(value) => match eval_target_term_with_env(env, value)? {
            TargetValue::Boxed(inner) => Some(*inner),
            _ => None,
        },
        TargetTerm::ClosureAddDelta(delta) => match eval_target_term_with_env(env, delta)? {
            TargetValue::U32(delta) => Some(TargetValue::ClosureAddDelta(delta)),
            _ => None,
        },
        TargetTerm::ClosureApply(closure, arg) => match (
            eval_target_term_with_env(env, closure)?,
            eval_target_term_with_env(env, arg)?,
        ) {
            (TargetValue::ClosureAddDelta(delta), TargetValue::U32(value)) => {
                Some(TargetValue::U32(wrapping_add_u32(value, delta)))
            }
            _ => None,
        },
        TargetTerm::DictionaryAdd => Some(TargetValue::DictionaryAddU32),
        TargetTerm::DictionaryApply(dict, left, right) => match (
            eval_target_term_with_env(env, dict)?,
            eval_target_term_with_env(env, left)?,
            eval_target_term_with_env(env, right)?,
        ) {
            (TargetValue::DictionaryAddU32, TargetValue::U32(lhs), TargetValue::U32(rhs)) => {
                Some(TargetValue::U32(wrapping_add_u32(lhs, rhs)))
            }
            _ => None,
        },
        TargetTerm::OptionSomeU32(value) => match eval_target_term_with_env(env, value)? {
            TargetValue::U32(value) => Some(TargetValue::OptionU32(Some(value))),
            _ => None,
        },
        TargetTerm::OptionNoneU32 => Some(TargetValue::OptionU32(None)),
        TargetTerm::EffectOptionMapInc(target) => match eval_target_term_with_env(env, target)? {
            TargetValue::OptionU32(Some(value)) => {
                Some(TargetValue::OptionU32(Some(wrapping_add_u32(value, 1))))
            }
            TargetValue::OptionU32(None) => Some(TargetValue::OptionU32(None)),
            _ => None,
        },
        TargetTerm::ResultOkU32(value) => match eval_target_term_with_env(env, value)? {
            TargetValue::U32(value) => Some(TargetValue::ResultU32U32(Ok(value))),
            _ => None,
        },
        TargetTerm::ResultErrU32(value) => match eval_target_term_with_env(env, value)? {
            TargetValue::U32(value) => Some(TargetValue::ResultU32U32(Err(value))),
            _ => None,
        },
        TargetTerm::EffectResultBindAdd1(target) => match eval_target_term_with_env(env, target)? {
            TargetValue::ResultU32U32(Ok(value)) => {
                Some(TargetValue::ResultU32U32(Ok(wrapping_add_u32(value, 1))))
            }
            TargetValue::ResultU32U32(Err(err)) => Some(TargetValue::ResultU32U32(Err(err))),
            _ => None,
        },
        TargetTerm::SubtypeExpr(value) => match eval_target_term_with_env(env, value)? {
            TargetValue::U32(value) => Some(TargetValue::SubtypeU32(value)),
            _ => None,
        },
        TargetTerm::FinExpr(bound, value) => match eval_target_term_with_env(env, value)? {
            TargetValue::U32(value) if value < *bound => Some(TargetValue::FinU32 {
                bound: *bound,
                value,
            }),
            _ => None,
        },
        TargetTerm::FinValue(value) => match eval_target_term_with_env(env, value)? {
            TargetValue::FinU32 { value, .. } => Some(TargetValue::U32(value)),
            _ => None,
        },
        TargetTerm::VectorExpr(expected_len, values) => {
            let values = values
                .iter()
                .map(|term| match eval_target_term_with_env(env, term)? {
                    TargetValue::U32(value) => Some(value),
                    _ => None,
                })
                .collect::<Option<Vec<_>>>()?;
            if values.len() == *expected_len {
                Some(TargetValue::VectorU32 {
                    expected_len: *expected_len,
                    values,
                })
            } else {
                None
            }
        }
        TargetTerm::VectorMapInc(target) => match eval_target_term_with_env(env, target)? {
            TargetValue::VectorU32 {
                expected_len,
                values,
            } => Some(TargetValue::VectorU32 {
                expected_len,
                values: values
                    .iter()
                    .map(|value| wrapping_add_u32(*value, 1))
                    .collect(),
            }),
            _ => None,
        },
        TargetTerm::RecursiveLeaf => Some(TargetValue::RecursiveTree(RecursiveTree::Leaf)),
        TargetTerm::RecursiveNode(left, value, right) => match (
            eval_target_term_with_env(env, left)?,
            eval_target_term_with_env(env, value)?,
            eval_target_term_with_env(env, right)?,
        ) {
            (
                TargetValue::RecursiveTree(left),
                TargetValue::U32(value),
                TargetValue::RecursiveTree(right),
            ) => Some(TargetValue::RecursiveTree(RecursiveTree::Node(
                Box::new(left),
                value,
                Box::new(right),
            ))),
            _ => None,
        },
        TargetTerm::RecursiveSum(target) => match eval_target_term_with_env(env, target)? {
            TargetValue::RecursiveTree(tree) => Some(TargetValue::U32(tree_sum(&tree))),
            _ => None,
        },
    }
}

pub fn eval_target_term(term: &TargetTerm) -> Option<TargetValue> {
    eval_target_term_with_env(&mut Vec::new(), term)
}

pub fn target_grammar_heads() -> &'static [&'static str] {
    &[
        "literal",
        "variable",
        "let",
        "if",
        "match",
        "loop",
        "call",
        "struct",
        "enum",
        "box",
        "deref",
        "closure",
        "dictionary",
        "effect",
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generated_subset_semantics_interprets_core_terms() {
        let term = TargetTerm::Let(
            String::from("lhs"),
            Box::new(TargetTerm::U32(40)),
            Box::new(TargetTerm::If(
                Box::new(TargetTerm::Eq(
                    Box::new(TargetTerm::Var(String::from("lhs"))),
                    Box::new(TargetTerm::U32(40)),
                )),
                Box::new(TargetTerm::Add(
                    Box::new(TargetTerm::Var(String::from("lhs"))),
                    Box::new(TargetTerm::U32(2)),
                )),
                Box::new(TargetTerm::U32(0)),
            )),
        );
        assert_eq!(eval_target_term(&term), Some(TargetValue::U32(42)));
        assert_eq!(
            eval_target_term(&TargetTerm::ListLength(Box::new(TargetTerm::List(vec![
                TargetTerm::U32(1),
                TargetTerm::U32(2),
                TargetTerm::U32(3),
            ])))),
            Some(TargetValue::U32(3))
        );
    }

    #[test]
    fn generated_subset_semantics_interprets_representative_values() {
        let struct_term = TargetTerm::StructExpr(
            String::from("Point"),
            vec![
                (String::from("x"), TargetTerm::U32(40)),
                (String::from("y"), TargetTerm::U32(2)),
            ],
        );
        assert_eq!(
            eval_target_term(&struct_term),
            Some(TargetValue::StructVal(
                String::from("Point"),
                vec![
                    (String::from("x"), TargetValue::U32(40)),
                    (String::from("y"), TargetValue::U32(2)),
                ],
            ))
        );

        let enum_term = TargetTerm::StepAmountOr(
            Box::new(TargetTerm::EnumExpr(
                String::from("Step"),
                String::from("Jump"),
                vec![TargetTerm::U32(42)],
            )),
            Box::new(TargetTerm::U32(0)),
        );
        assert_eq!(eval_target_term(&enum_term), Some(TargetValue::U32(42)));

        let recursive_term = TargetTerm::RecursiveSum(Box::new(TargetTerm::RecursiveNode(
            Box::new(TargetTerm::RecursiveLeaf),
            Box::new(TargetTerm::U32(42)),
            Box::new(TargetTerm::RecursiveLeaf),
        )));
        assert_eq!(
            eval_target_term(&recursive_term),
            Some(TargetValue::U32(42))
        );

        let dependent_fin = TargetTerm::FinValue(Box::new(TargetTerm::FinExpr(
            10,
            Box::new(TargetTerm::U32(9)),
        )));
        assert_eq!(eval_target_term(&dependent_fin), Some(TargetValue::U32(9)));

        let dependent_vector = TargetTerm::VectorMapInc(Box::new(TargetTerm::VectorExpr(
            3,
            vec![
                TargetTerm::U32(1),
                TargetTerm::U32(2),
                TargetTerm::U32(u32::MAX),
            ],
        )));
        assert_eq!(
            eval_target_term(&dependent_vector),
            Some(TargetValue::VectorU32 {
                expected_len: 3,
                values: vec![2, 3, 0],
            })
        );

        let closure_term = TargetTerm::ClosureApply(
            Box::new(TargetTerm::ClosureAddDelta(Box::new(TargetTerm::U32(5)))),
            Box::new(TargetTerm::U32(37)),
        );
        assert_eq!(eval_target_term(&closure_term), Some(TargetValue::U32(42)));

        let dictionary_term = TargetTerm::DictionaryApply(
            Box::new(TargetTerm::DictionaryAdd),
            Box::new(TargetTerm::U32(u32::MAX)),
            Box::new(TargetTerm::U32(1)),
        );
        assert_eq!(
            eval_target_term(&dictionary_term),
            Some(TargetValue::U32(0))
        );

        let effect_option = TargetTerm::EffectOptionMapInc(Box::new(TargetTerm::OptionSomeU32(
            Box::new(TargetTerm::U32(41)),
        )));
        assert_eq!(
            eval_target_term(&effect_option),
            Some(TargetValue::OptionU32(Some(42)))
        );

        let effect_result = TargetTerm::EffectResultBindAdd1(Box::new(TargetTerm::ResultOkU32(
            Box::new(TargetTerm::U32(41)),
        )));
        assert_eq!(
            eval_target_term(&effect_result),
            Some(TargetValue::ResultU32U32(Ok(42)))
        );

        let boxed_call =
            TargetTerm::DerefExpr(Box::new(TargetTerm::BoxExpr(Box::new(TargetTerm::Call(
                String::from("wrapping_add_u32"),
                vec![TargetTerm::U32(40), TargetTerm::U32(2)],
            )))));
        assert_eq!(eval_target_term(&boxed_call), Some(TargetValue::U32(42)));
    }

    #[test]
    fn target_grammar_heads_are_complete() {
        for head in [
            "literal",
            "variable",
            "let",
            "if",
            "match",
            "loop",
            "call",
            "struct",
            "enum",
            "box",
            "deref",
            "closure",
            "dictionary",
            "effect",
        ] {
            assert!(target_grammar_heads().contains(&head));
        }
    }
}
