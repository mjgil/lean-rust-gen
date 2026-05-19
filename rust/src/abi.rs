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
}
