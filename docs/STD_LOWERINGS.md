# Std lowerings

Lean/Std lowerings are admitted only when they have an extractor-backed
implementation row, ownership rule, tests, and documentation.

## Completed lowerings

The completed table lives in `LeanRustCore.StdImplementation.lowerings`. The
current direct extractor-backed slice is:

| Lean constant | Exported Lean example | Rust shape | Ownership |
| --- | --- | --- | --- |
| `List.map` | `list_map_inc_u32` | loop with `Vec::push` | returned new value |
| `List.filter` | `list_filter_nonzero_u32` | loop with predicate guard | returned new value |
| `List.foldl` | `list_fold_sum_u32` | mutable accumulator loop | owned |
| `List.foldr` | `list_foldr_sum_u32` | reverse iterator plus accumulator | owned |
| `List.any` | `list_any_nonzero_u32` | short-circuit bool loop | borrowed read-only |
| `List.all` | `list_all_nonzero_u32` | short-circuit bool loop | borrowed read-only |
| `List.append` | `list_append_u32` | owned `Vec::extend` | owned |
| `List.find?` | `list_find_nonzero_u32` | loop returning `Option` | borrowed read-only |
| `List.reverse` | `list_reverse_first_or_u32` | runtime reverse helper | owned |
| `Array.map` | `array_map_inc_u32` | loop with `Vec::push` | returned new value |
| `Array.foldl` | `array_fold_sum_u32` | mutable accumulator loop | owned |
| `Array.push` | `array_push_u32` | owned `Vec::push` | owned |
| `Array.get?` | `array_get_opt_u32` | runtime borrowed-slice get helper | borrowed read-only |
| `Option.map` | `option_map_inc_u32` | `match Option` | owned |
| `Option.bind` | `option_bind_inc_u32` | `match Option` | owned |
| `Option.getD` | `option_getd_u32` | `match Option` with fallback | owned |
| `Except.map` | `result_map_ok_inc_u32` | `match Result` ok branch | owned |
| `Except.bind` | `except_do_inc_u32` | `match Result` | owned |
| `Except.mapError` | `result_map_err_inc_u32` | `match Result` err branch | owned |
| `String.append` | `string_append_lean` | runtime owned-string append helper | owned |
| `String.length` | `string_length_chars_u32` | runtime char-count helper | borrowed read-only |
| `String.contains` | `string_contains_char_lean` | runtime char-membership helper | borrowed read-only |

`List.zip` and `Array.set` remain runtime/helper-only and are not counted as
extractor-complete lowerings in this document. They cannot be marked complete
until the generated Lean→Rust lane has direct exported examples, target
validation coverage, and stable ownership semantics for their intermediate
runtime shapes.

## Implementation requirements

- `LeanRustCore.StdImplementation.lowerings` records each admitted Lean/Std constant.
- Each row records the Rust shape, ownership mode, test owner, and documentation owner.
- Every admitted row must have a real `@[rust_export]` example, generated Rust, and target-validation evidence.
- Runtime helpers may back extractor lowering, but runtime-only helpers do not count as completed extractor coverage.

## Tests required before completion

Each lowered constant must have at least one generated Lean→Rust test or
target-interpreter path plus runtime coverage where ownership-sensitive helper
behavior matters. Positive corpus fixtures for the extractor-backed examples
must stay in sync with `scripts/check-next-20-completion.py` and
`rust/tests/next20_completion.rs`.

## Documentation required before completion

This document must list each admitted Lean constant, its Rust shape, ownership
behavior, and the exported Lean example proving the extractor path. Registry-only
or runtime-only lowerings cannot be marked complete.
