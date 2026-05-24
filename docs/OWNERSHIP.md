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
| exact BigUint/BigInt arithmetic | temporary shared operand borrows | owned result | `&(expr)` operands for `+`, `-`, `*`, and `<` |

## Implementation requirements

Ownership rules live in `LeanRustCore.OwnershipPolicy.rules`. The parser and
validation gates reject ad-hoc references or lifetimes that are not covered by
this policy table. In the direct generated lane, the only emitted borrow shape
is temporary shared operand borrows for exact BigUint/BigInt arithmetic. The
generated Rust must emit no reference types in public or private declarations
and no explicit lifetimes anywhere in the generated file.

## Tests required before completion

Tests must cover owned container transforms, read-only borrowed helpers,
clone-insertion helpers, string ownership, recursive `Box`, `Rc`, and arena
layouts. Parser-backed validation must also prove that generated Rust uses only
the approved temporary shared operand borrows and that no reference types or
explicit lifetimes are emitted.

## Documentation required before completion

This document must describe every admitted ownership mode and must state whether
references can escape. In this milestone, generated references do not escape:
the direct lane emits only temporary shared operand borrows and never emits
escaping borrowed parameters, borrowed return values, or lifetime annotations.
