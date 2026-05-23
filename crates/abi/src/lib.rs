//! Raw ABI helpers and opaque handles for generated Lean→Rust output.
//!
//! This crate is intentionally separate from the default generated safe lane.
//! Unsafe functions are documented at the boundary, and every owned handle has
//! an explicit destructor.

use std::collections::BTreeMap;
use std::sync::{Mutex, OnceLock};

#[repr(transparent)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ChStatus(pub i32);

impl ChStatus {
    pub const OK: Self = Self(0);
    pub const ERR: Self = Self(1);

    pub const fn is_ok(self) -> bool {
        self.0 == 0
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PanicPolicy {
    Abort,
    CatchUnwind,
    Forbidden,
}

pub fn result_to_status<T, E>(result: &Result<T, E>) -> ChStatus {
    match result {
        Ok(_) => ChStatus::OK,
        Err(_) => ChStatus::ERR,
    }
}

/// Lower `Result<u32,u32>` into status plus optional out-parameters.
///
/// # Safety
///
/// `out_ok` and `out_err` may be null. If they are non-null, they must be
/// valid, aligned, writable pointers to `u32` for the duration of the call.
pub unsafe fn lower_result_u32_u32(
    result: Result<u32, u32>,
    out_ok: *mut u32,
    out_err: *mut u32,
) -> ChStatus {
    match result {
        Ok(value) => {
            if !out_ok.is_null() {
                unsafe {
                    *out_ok = value;
                }
            }
            ChStatus::OK
        }
        Err(value) => {
            if !out_err.is_null() {
                unsafe {
                    *out_err = value;
                }
            }
            ChStatus::ERR
        }
    }
}

#[repr(transparent)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct LrcHandle(pub u64);

#[derive(Default)]
struct HandleStore<T> {
    next: u64,
    values: BTreeMap<u64, T>,
}

impl<T> HandleStore<T> {
    fn insert(&mut self, value: T) -> LrcHandle {
        self.next = self.next.wrapping_add(1).max(1);
        let handle = LrcHandle(self.next);
        self.values.insert(handle.0, value);
        handle
    }

    fn get(&self, handle: LrcHandle) -> Option<&T> {
        self.values.get(&handle.0)
    }

    fn get_mut(&mut self, handle: LrcHandle) -> Option<&mut T> {
        self.values.get_mut(&handle.0)
    }

    fn remove(&mut self, handle: LrcHandle) -> bool {
        self.values.remove(&handle.0).is_some()
    }
}

static VEC_U32_HANDLES: OnceLock<Mutex<HandleStore<Vec<u32>>>> = OnceLock::new();
static STRING_HANDLES: OnceLock<Mutex<HandleStore<String>>> = OnceLock::new();

fn vec_store() -> &'static Mutex<HandleStore<Vec<u32>>> {
    VEC_U32_HANDLES.get_or_init(|| Mutex::new(HandleStore::default()))
}

fn string_store() -> &'static Mutex<HandleStore<String>> {
    STRING_HANDLES.get_or_init(|| Mutex::new(HandleStore::default()))
}

pub fn vec_u32_handle_new() -> LrcHandle {
    vec_store()
        .lock()
        .expect("handle mutex poisoned")
        .insert(Vec::new())
}

pub fn vec_u32_handle_drop(handle: LrcHandle) -> ChStatus {
    if vec_store()
        .lock()
        .expect("handle mutex poisoned")
        .remove(handle)
    {
        ChStatus::OK
    } else {
        ChStatus::ERR
    }
}

pub fn vec_u32_handle_push(handle: LrcHandle, value: u32) -> ChStatus {
    let mut store = vec_store().lock().expect("handle mutex poisoned");
    if let Some(vec) = store.get_mut(handle) {
        vec.push(value);
        ChStatus::OK
    } else {
        ChStatus::ERR
    }
}

pub fn vec_u32_handle_len(handle: LrcHandle) -> Result<usize, ChStatus> {
    let store = vec_store().lock().expect("handle mutex poisoned");
    store.get(handle).map(Vec::len).ok_or(ChStatus::ERR)
}

pub fn string_handle_from_u32(value: u32) -> LrcHandle {
    string_store()
        .lock()
        .expect("handle mutex poisoned")
        .insert(value.to_string())
}

pub fn string_handle_drop(handle: LrcHandle) -> ChStatus {
    if string_store()
        .lock()
        .expect("handle mutex poisoned")
        .remove(handle)
    {
        ChStatus::OK
    } else {
        ChStatus::ERR
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn result_lowering_handles_null_out_params() {
        let status =
            unsafe { lower_result_u32_u32(Ok(7), std::ptr::null_mut(), std::ptr::null_mut()) };
        assert_eq!(status, ChStatus::OK);
    }

    #[test]
    fn vec_handle_lifecycle_rejects_double_drop() {
        let handle = vec_u32_handle_new();
        assert_eq!(vec_u32_handle_push(handle, 42), ChStatus::OK);
        assert_eq!(vec_u32_handle_len(handle), Ok(1));
        assert_eq!(vec_u32_handle_drop(handle), ChStatus::OK);
        assert_eq!(vec_u32_handle_drop(handle), ChStatus::ERR);
    }

    #[test]
    fn string_handle_has_explicit_destructor() {
        let handle = string_handle_from_u32(42);
        assert_eq!(string_handle_drop(handle), ChStatus::OK);
        assert_eq!(string_handle_drop(handle), ChStatus::ERR);
    }
}
