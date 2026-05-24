pub fn call_payload<'a>(expr: &'a str, name: &str) -> Option<&'a str> {
    expr.strip_prefix(&(name.to_owned() + "("))
        .and_then(|body| body.strip_suffix(')'))
}

pub fn split_top_level(input: &str, delimiter: char) -> Vec<&str> {
    let mut pieces = Vec::new();
    let mut start = 0usize;
    let mut angle_depth = 0i32;
    let mut paren_depth = 0i32;

    for (idx, ch) in input.char_indices() {
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

pub fn split_top_args(input: &str) -> Vec<&str> {
    split_top_level(input, ',')
}
