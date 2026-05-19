# Trusted core and gates

## Trusted definitions

- `LeanRustCore.Extract.extractConst`
- `LeanRustCore.Surface.SurfaceExpr`
- `LeanRustCore.Surface.typeOf`
- `LeanRustCore.EmitRust.emitSurfaceRustModule`
- `LeanRustCore.IR.RType`
- `LeanRustCore.IR.RExpr`
- `LeanRustCore.IR.eval`
- `LeanRustCore.ChimeraBoundary.lowerResultSignature`

## CI gates

```bash
./scripts/check-no-placeholders.sh
lake build
./scripts/check-extractor-snapshot.sh
cd rust && cargo fmt --check
cd rust && cargo clippy -- -D warnings
cd rust && cargo test
```

The snapshot gate is important: it proves the checked-in Rust fallback is exactly
what the Lean extractor emits.

## Current limitations

The extractor supports a deliberately small Lean subset: ordinary `def`s whose
arguments and return values are `Nat`/`Bool`, plus `if`, `let`, Nat comparisons,
Nat arithmetic, Bool literals, and simple equality. The next milestones are
structs/enums, pattern matching, `Option`, `Except`, and monomorphized generics.
