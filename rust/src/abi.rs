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

#[cfg(feature = "ffi")]
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn status_reports_ok() {
        assert!(ChStatus::OK.is_ok());
        assert!(!ChStatus::ERR.is_ok());
    }

    #[test]
    fn result_status_distinguishes_variants() {
        assert_eq!(result_to_status::<u32, u32>(&Ok(1)), ChStatus::OK);
        assert_eq!(result_to_status::<u32, u32>(&Err(2)), ChStatus::ERR);
    }

    #[cfg(feature = "ffi")]
    #[test]
    fn result_lowering_writes_only_selected_out_param() {
        let mut ok = 0u32;
        let mut err = 0u32;

        let status = unsafe { lower_result_u32_u32(Ok(7), &mut ok, &mut err) };
        assert_eq!(status, ChStatus::OK);
        assert_eq!(ok, 7);
        assert_eq!(err, 0);

        let status = unsafe { lower_result_u32_u32(Err(9), &mut ok, &mut err) };
        assert_eq!(status, ChStatus::ERR);
        assert_eq!(ok, 7);
        assert_eq!(err, 9);
    }
}
