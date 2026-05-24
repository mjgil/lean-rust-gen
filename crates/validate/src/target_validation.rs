use std::fmt;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TargetValidationArg {
    pub name: String,
    pub ty: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TargetValidationFunction {
    pub args: Vec<TargetValidationArg>,
    pub fingerprint: String,
    pub name: String,
    pub ret: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TargetValidationParseError {
    details: String,
}

impl TargetValidationParseError {
    fn new(details: impl Into<String>) -> Self {
        Self {
            details: details.into(),
        }
    }
}

impl fmt::Display for TargetValidationParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.details)
    }
}

impl std::error::Error for TargetValidationParseError {}

fn split_top_level(input: &str, delimiter: char) -> Vec<&str> {
    let mut pieces = Vec::new();
    let mut start = 0usize;
    let mut angle_depth = 0i32;
    let mut paren_depth = 0i32;
    let chars: Vec<(usize, char)> = input.char_indices().collect();

    for (idx, ch) in chars {
        match ch {
            '<' => angle_depth += 1,
            '>' => {
                let prev = input[..idx].chars().next_back();
                if prev != Some('-') && angle_depth > 0 {
                    angle_depth -= 1;
                }
            }
            '(' => paren_depth += 1,
            ')' => paren_depth -= 1,
            _ if ch == delimiter && angle_depth == 0 && paren_depth == 0 => {
                pieces.push(input[start..idx].trim());
                start = idx + ch.len_utf8();
            }
            _ => {}
        }
    }

    let tail = input[start..].trim();
    if !tail.is_empty() {
        pieces.push(tail);
    }
    pieces
}

fn parse_arg(piece: &str) -> Result<TargetValidationArg, TargetValidationParseError> {
    let mut angle_depth = 0i32;
    let mut paren_depth = 0i32;

    for (idx, ch) in piece.char_indices() {
        match ch {
            '<' => angle_depth += 1,
            '>' => {
                let prev = piece[..idx].chars().next_back();
                if prev != Some('-') && angle_depth > 0 {
                    angle_depth -= 1;
                }
            }
            '(' => paren_depth += 1,
            ')' => paren_depth -= 1,
            ':' if angle_depth == 0 && paren_depth == 0 => {
                return Ok(TargetValidationArg {
                    name: piece[..idx].trim().to_string(),
                    ty: piece[idx + 1..].trim().to_string(),
                });
            }
            _ => {}
        }
    }

    Err(TargetValidationParseError::new(format!(
        "could not parse target-validation arg {piece}"
    )))
}

pub fn parse_target_validation_functions(
    snapshot: &str,
) -> Result<Vec<TargetValidationFunction>, TargetValidationParseError> {
    let mut functions = Vec::new();

    for line in snapshot.lines() {
        let mut parts = line.split('\t');
        if parts.next() != Some("FN") {
            continue;
        }

        let name = parts.next().ok_or_else(|| {
            TargetValidationParseError::new("missing target-validation function name")
        })?;
        let arg_text = parts.next().ok_or_else(|| {
            TargetValidationParseError::new(format!(
                "missing args for target-validation function {name}"
            ))
        })?;
        let ret = parts.next().ok_or_else(|| {
            TargetValidationParseError::new(format!(
                "missing return type for target-validation function {name}"
            ))
        })?;
        let fingerprint = parts.next().ok_or_else(|| {
            TargetValidationParseError::new(format!(
                "missing fingerprint for target-validation function {name}"
            ))
        })?;

        let args = if arg_text.is_empty() {
            Vec::new()
        } else {
            split_top_level(arg_text, ',')
                .into_iter()
                .map(parse_arg)
                .collect::<Result<Vec<_>, _>>()?
        };

        functions.push(TargetValidationFunction {
            args,
            fingerprint: fingerprint.to_string(),
            name: name.to_string(),
            ret: ret.to_string(),
        });
    }

    Ok(functions)
}

#[cfg(test)]
mod tests {
    use super::*;

    const TARGET_VALIDATION_SNAPSHOT: &str = include_str!("../../../rust/target-validation.txt");

    #[test]
    fn parses_current_target_validation_snapshot() {
        let functions = parse_target_validation_functions(TARGET_VALIDATION_SNAPSHOT).unwrap();
        assert_eq!(functions.len(), 126);
        assert!(functions.iter().any(|function| {
            function.name == "unsupported_higher_order_u32"
                && function.args
                    == vec![
                        TargetValidationArg {
                            name: String::from("f"),
                            ty: String::from("fn(u32) -> u32"),
                        },
                        TargetValidationArg {
                            name: String::from("x"),
                            ty: String::from("u32"),
                        },
                    ]
        }));
        assert!(functions.iter().any(|function| {
            function.name == "generic_option_default__step"
                && function.args.iter().any(|arg| arg.ty == "Option<Step>")
        }));
    }
}
