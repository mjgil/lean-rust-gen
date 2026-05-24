use crate::{
    string_handle_drop, string_handle_from_u32, vec_u32_handle_drop, vec_u32_handle_len,
    vec_u32_handle_new, vec_u32_handle_push, ChStatus, LrcHandle,
};

#[derive(Clone, Debug, PartialEq, Eq)]
struct PropertyRng {
    state: u64,
}

impl PropertyRng {
    fn seeded(seed: u64) -> Self {
        Self {
            state: seed ^ 0xE703_7ED1_A0B4_28DB,
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

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum HandleTraceOp {
    VecNew,
    VecPush(u32),
    VecLen,
    VecDrop,
    StringFromU32(u32),
    StringDrop,
}

pub fn generate_handle_traces(seed: u64, count: usize, max_ops: usize) -> Vec<Vec<HandleTraceOp>> {
    let mut rng = PropertyRng::seeded(seed);
    let mut traces = Vec::with_capacity(count);
    for _ in 0..count {
        let mut trace = vec![HandleTraceOp::VecNew];
        for idx in 1..max_ops.max(2) {
            trace.push(match idx % 5 {
                0 => HandleTraceOp::VecPush(rng.next_u32()),
                1 => HandleTraceOp::VecLen,
                2 => HandleTraceOp::VecDrop,
                3 => HandleTraceOp::StringFromU32(rng.next_u32()),
                _ => HandleTraceOp::StringDrop,
            });
        }
        traces.push(trace);
    }
    traces
}

pub fn shrink_handle_trace(trace: &[HandleTraceOp]) -> Vec<Vec<HandleTraceOp>> {
    if trace.len() <= 1 {
        return Vec::new();
    }
    let mut out = Vec::new();
    out.push(vec![HandleTraceOp::VecDrop]);
    out.push(vec![HandleTraceOp::StringDrop]);
    if trace.len() > 1 {
        out.push(trace[..trace.len() / 2].to_vec());
        out.push(vec![HandleTraceOp::VecNew, HandleTraceOp::VecDrop]);
    }
    out
}

pub fn minimize_handle_trace<F>(
    mut current: Vec<HandleTraceOp>,
    mut predicate: F,
) -> Vec<HandleTraceOp>
where
    F: FnMut(&[HandleTraceOp]) -> bool,
{
    loop {
        let mut next = None;
        for candidate in shrink_handle_trace(&current) {
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

pub fn execute_handle_trace(trace: &[HandleTraceOp]) -> Vec<ChStatus> {
    let mut statuses = Vec::new();
    let mut vec_handle: Option<LrcHandle> = None;
    let mut string_handle: Option<LrcHandle> = None;

    for op in trace {
        match *op {
            HandleTraceOp::VecNew => {
                vec_handle = Some(vec_u32_handle_new());
                statuses.push(ChStatus::OK);
            }
            HandleTraceOp::VecPush(value) => {
                statuses.push(
                    vec_handle
                        .map(|handle| vec_u32_handle_push(handle, value))
                        .unwrap_or(ChStatus::ERR),
                );
            }
            HandleTraceOp::VecLen => {
                statuses.push(
                    vec_handle
                        .and_then(|handle| vec_u32_handle_len(handle).ok().map(|_| ChStatus::OK))
                        .unwrap_or(ChStatus::ERR),
                );
            }
            HandleTraceOp::VecDrop => {
                let status = vec_handle.map(vec_u32_handle_drop).unwrap_or(ChStatus::ERR);
                if status.is_ok() {
                    vec_handle = None;
                }
                statuses.push(status);
            }
            HandleTraceOp::StringFromU32(value) => {
                string_handle = Some(string_handle_from_u32(value));
                statuses.push(ChStatus::OK);
            }
            HandleTraceOp::StringDrop => {
                let status = string_handle
                    .map(string_handle_drop)
                    .unwrap_or(ChStatus::ERR);
                if status.is_ok() {
                    string_handle = None;
                }
                statuses.push(status);
            }
        }
    }

    statuses
}
