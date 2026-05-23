# Std lowerings

Lean/Std lowerings are admitted only when they have an implementation row,
ownership rule, tests, and documentation.

## Completed lowerings

The completed table lives in `LeanRustCore.StdImplementation.lowerings` and
covers List, Array, Option, Except, and String families including map, filter,
folds, any/all, append, find, reverse, zip, push, get, set, bind, mapError,
append, length, and contains.

## Implementation requirements

- `LeanRustCore.StdImplementation.implemented` records each admitted Lean/Std constant.
- Each row records the Rust shape, ownership mode, test owner, and documentation owner.
- Runtime helpers must cover owned and borrowed lowering forms before a Std constant is marked complete.

## Tests required before completion

Each lowered constant must have at least one generated or runtime test, plus a
property seed for boundary values where applicable. Ownership-sensitive lowerings
must also be covered by `docs/OWNERSHIP.md`.

## Documentation required before completion

This document must list each admitted Lean constant, its Rust shape, and its
ownership behavior. Registry-only lowerings cannot be marked complete.
