# Typeclass specialization

The current milestone completes resolved monomorphic typeclass specialization,
not general dictionary passing.

## Supported families

- `BEq`
- `DecidableEq` / `Decidable`
- `Ord`, `LT`, `LE`
- numeric operation classes for admitted numeric modes
- `Inhabited`
- `ToString`
- `Repr`
- pure `Option` and `Except` `Functor`/`Applicative`/`Monad` shells

## Implementation requirements

`LeanRustCore.TypeclassSpecialization.classes` records each class family, the
specialization shape, supported concrete types, required tests, and required
documentation. Unresolved dictionaries are rejected with `LRC001`.

## Tests required before completion

Tests must cover each supported class at concrete types and at least one
unsupported unresolved dictionary. Runtime dictionary helper tests cover the
monomorphic dictionary structs used outside the generated safe lane.

## Documentation required before completion

This document must distinguish specialization from generated dictionaries.
Generated dictionaries are a later milestone and are not required for rows 21–40.
