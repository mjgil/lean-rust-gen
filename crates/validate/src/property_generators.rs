use crate::{eval_target_term, RecursiveTree, TargetTerm, TargetValue};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PropertyRng {
    state: u64,
}

impl PropertyRng {
    pub fn seeded(seed: u64) -> Self {
        Self {
            state: seed ^ 0xA076_1D64_78BD_642F,
        }
    }

    fn next_u64(&mut self) -> u64 {
        self.state ^= self.state << 7;
        self.state ^= self.state >> 9;
        self.state ^= self.state << 8;
        self.state
    }

    fn next_u32(&mut self) -> u32 {
        self.next_u64() as u32
    }
}

pub fn target_term_head(term: &TargetTerm) -> &'static str {
    match term {
        TargetTerm::Unit | TargetTerm::Bool(_) | TargetTerm::U32(_) | TargetTerm::Value(_) => {
            "literal"
        }
        TargetTerm::Var(_) => "variable",
        TargetTerm::Let(_, _, _) => "let",
        TargetTerm::If(_, _, _) => "if",
        TargetTerm::Call(_, _) => "call",
        TargetTerm::StructExpr(_, _) => "struct",
        TargetTerm::EnumExpr(_, _, _) => "enum",
        TargetTerm::BoxExpr(_) => "box",
        TargetTerm::DerefExpr(_) => "deref",
        TargetTerm::OptionSomeU32(_)
        | TargetTerm::ResultOkU32(_)
        | TargetTerm::ResultErrU32(_)
        | TargetTerm::EffectOptionMapInc(_)
        | TargetTerm::EffectResultBindAdd1(_) => "effect",
        TargetTerm::ClosureAddDelta(_) | TargetTerm::ClosureApply(_, _) => "closure",
        TargetTerm::DictionaryAdd | TargetTerm::DictionaryApply(_, _, _) => "dictionary",
        _ => "match",
    }
}

fn literal_u32(rng: &mut PropertyRng) -> TargetTerm {
    TargetTerm::U32(rng.next_u32())
}

fn recursive_tree_value(value: u32) -> TargetValue {
    TargetValue::RecursiveTree(RecursiveTree::Node(
        Box::new(RecursiveTree::Leaf),
        value,
        Box::new(RecursiveTree::Leaf),
    ))
}

pub fn generate_target_term_cases(seed: u64, count: usize, max_depth: usize) -> Vec<TargetTerm> {
    let mut rng = PropertyRng::seeded(seed);
    let mut out = Vec::with_capacity(count);
    for idx in 0..count {
        out.push(match idx % 15 {
            0 => literal_u32(&mut rng),
            1 => TargetTerm::Let(
                String::from("x"),
                Box::new(literal_u32(&mut rng)),
                Box::new(TargetTerm::Var(String::from("x"))),
            ),
            2 => TargetTerm::If(
                Box::new(TargetTerm::Bool(true)),
                Box::new(literal_u32(&mut rng)),
                Box::new(TargetTerm::U32(0)),
            ),
            3 => TargetTerm::ListLength(Box::new(TargetTerm::List(vec![
                literal_u32(&mut rng),
                literal_u32(&mut rng),
            ]))),
            4 => TargetTerm::Call(
                String::from("wrapping_add_u32"),
                vec![literal_u32(&mut rng), literal_u32(&mut rng)],
            ),
            5 => TargetTerm::StructExpr(
                String::from("Point"),
                vec![
                    (String::from("x"), literal_u32(&mut rng)),
                    (String::from("y"), literal_u32(&mut rng)),
                ],
            ),
            6 => TargetTerm::EnumExpr(
                String::from("Step"),
                String::from("Jump"),
                vec![literal_u32(&mut rng)],
            ),
            7 => TargetTerm::StepAmountOr(
                Box::new(TargetTerm::EnumExpr(
                    String::from("Step"),
                    String::from("Jump"),
                    vec![literal_u32(&mut rng)],
                )),
                Box::new(TargetTerm::U32(0)),
            ),
            8 => TargetTerm::BoxExpr(Box::new(literal_u32(&mut rng))),
            9 => TargetTerm::DerefExpr(Box::new(TargetTerm::BoxExpr(Box::new(literal_u32(
                &mut rng,
            ))))),
            10 => TargetTerm::ClosureApply(
                Box::new(TargetTerm::ClosureAddDelta(Box::new(literal_u32(&mut rng)))),
                Box::new(literal_u32(&mut rng)),
            ),
            11 => TargetTerm::DictionaryApply(
                Box::new(TargetTerm::DictionaryAdd),
                Box::new(literal_u32(&mut rng)),
                Box::new(literal_u32(&mut rng)),
            ),
            12 => TargetTerm::EffectResultBindAdd1(Box::new(TargetTerm::ResultOkU32(Box::new(
                literal_u32(&mut rng),
            )))),
            13 => TargetTerm::VectorMapInc(Box::new(TargetTerm::VectorExpr(
                max_depth.max(1),
                (0..max_depth.max(1))
                    .map(|_| literal_u32(&mut rng))
                    .collect(),
            ))),
            _ => TargetTerm::RecursiveSum(Box::new(TargetTerm::Value(recursive_tree_value(
                rng.next_u32(),
            )))),
        });
    }
    out
}

pub fn shrink_target_term(term: &TargetTerm) -> Vec<TargetTerm> {
    match term {
        TargetTerm::U32(value) if *value > 2 => vec![
            TargetTerm::U32(0),
            TargetTerm::U32(1),
            TargetTerm::U32(2),
            TargetTerm::U32(value / 2),
        ],
        TargetTerm::U32(2) => Vec::new(),
        TargetTerm::U32(value) if *value > 0 => {
            vec![TargetTerm::U32(0), TargetTerm::U32(1)]
        }
        TargetTerm::Let(_, value, body) => vec![value.as_ref().clone(), body.as_ref().clone()],
        TargetTerm::If(_, when_true, when_false) => {
            vec![when_true.as_ref().clone(), when_false.as_ref().clone()]
        }
        TargetTerm::StructExpr(_, fields) if !fields.is_empty() => vec![fields[0].1.clone()],
        TargetTerm::EnumExpr(_, _, payload) if !payload.is_empty() => payload.clone(),
        TargetTerm::BoxExpr(inner)
        | TargetTerm::DerefExpr(inner)
        | TargetTerm::ClosureAddDelta(inner)
        | TargetTerm::OptionSomeU32(inner)
        | TargetTerm::ResultOkU32(inner)
        | TargetTerm::ResultErrU32(inner)
        | TargetTerm::EffectOptionMapInc(inner)
        | TargetTerm::EffectResultBindAdd1(inner)
        | TargetTerm::SubtypeExpr(inner)
        | TargetTerm::FinValue(inner)
        | TargetTerm::VectorMapInc(inner)
        | TargetTerm::RecursiveSum(inner) => vec![inner.as_ref().clone()],
        TargetTerm::Add(left, right)
        | TargetTerm::Eq(left, right)
        | TargetTerm::ClosureApply(left, right) => {
            vec![left.as_ref().clone(), right.as_ref().clone()]
        }
        TargetTerm::DictionaryApply(dict, left, right) => {
            vec![
                dict.as_ref().clone(),
                left.as_ref().clone(),
                right.as_ref().clone(),
            ]
        }
        TargetTerm::VectorExpr(_, values) if !values.is_empty() => {
            vec![TargetTerm::VectorExpr(0, Vec::new())]
        }
        TargetTerm::RecursiveNode(left, value, right) => {
            vec![
                left.as_ref().clone(),
                value.as_ref().clone(),
                right.as_ref().clone(),
            ]
        }
        _ => Vec::new(),
    }
}

pub fn minimize_target_term<F>(mut current: TargetTerm, mut predicate: F) -> TargetTerm
where
    F: FnMut(&TargetTerm) -> bool,
{
    loop {
        let mut next = None;
        for candidate in shrink_target_term(&current) {
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

pub fn generated_terms_are_well_typed(seed: u64, count: usize, max_depth: usize) -> bool {
    generate_target_term_cases(seed, count, max_depth)
        .iter()
        .all(|term| eval_target_term(term).is_some())
}
