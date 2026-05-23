#![forbid(unsafe_code)]
//! C header generation for the feature-gated raw ABI lane.

pub fn generated_c_header() -> &'static str {
    r#"#ifndef LEAN_RUST_CORE_ABI_H
#define LEAN_RUST_CORE_ABI_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef int32_t LrcStatus;
typedef uint64_t LrcHandle;

/* Ownership: returned handles are owned by the caller and must be dropped. */
LrcHandle lrc_vec_u32_handle_new(void);
LrcStatus lrc_vec_u32_handle_drop(LrcHandle handle);
LrcStatus lrc_vec_u32_handle_push(LrcHandle handle, uint32_t value);
LrcStatus lrc_vec_u32_handle_len(LrcHandle handle, size_t *out_len);
LrcHandle lrc_string_handle_from_u32(uint32_t value);
LrcStatus lrc_string_handle_drop(LrcHandle handle);

#ifdef __cplusplus
}
#endif

#endif /* LEAN_RUST_CORE_ABI_H */
"#
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn header_contains_ownership_and_destructors() {
        let header = generated_c_header();
        assert!(header.contains("Ownership"));
        assert!(header.contains("lrc_vec_u32_handle_drop"));
        assert!(header.contains("lrc_string_handle_drop"));
        assert!(header.contains("extern \"C\""));
    }
}
