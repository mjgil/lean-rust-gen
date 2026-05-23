# Ownership and borrowing policy

Generated Rust is safe Rust. The default policy is owned values. Borrowing is
admitted only for read-only helpers whose references do not escape.

| Shape | Input mode | Output mode | Rust shape |
|---|---|---|---|
| small scalars | owned | owned | by value |
| consumed `Vec<T>` | owned | owned | `into_iter`/for loop |
| read-only `Vec<T>` | shared borrow | owned/copy result | `&[T]` |
| `String` append | owned + shared suffix | owned | `String::push_str` |
| recursive payload | boxed/shared/arena | layout-specific | `Box`, `Rc`, or arena index |

## Implementation requirements

Ownership rules live in `LeanRustCore.OwnershipPolicy.rules`. The parser and
validation gates reject ad-hoc references or lifetimes that are not covered by
this policy table.

## Tests required before completion

Tests must cover owned container transforms, read-only borrowed helpers,
clone-insertion helpers, string ownership, recursive `Box`, `Rc`, and arena
layouts.

## Documentation required before completion

This document must describe every admitted ownership mode and must state whether
references can escape. In this milestone, generated references do not escape.
