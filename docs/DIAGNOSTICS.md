# User-facing diagnostics

Unsupported Lean must produce stable, actionable diagnostics. Every diagnostic
has a source declaration, construct kind, next feature, documentation link, and a
snapshot in the negative or unsupported corpus. Diagnostics also carry source-span metadata through
`SourceSpan`: file/range when Lean metadata can provide it, or a stable
unknown-span fallback when it cannot.

| Code | Meaning | Next feature |
|---|---|---|
| `LRC001` | Unresolved typeclass dictionary | Generated typeclass dictionaries |
| `LRC002` | Dependent runtime match | Dependent erasure checker |
| `LRC003` | Escaping captured closure | First-class closure object |
| `LRC004` | IO or external effect | Controlled IO boundary |
| `LRC005` | Rust hygiene collision | Rename source declaration or binder |
| `LRC006` | Unsupported recursor or equation-compiler shape | General recursion lowering |
| `LRC007` | Unsupported Std or library constant | Std lowering implementation |
| `LRC008` | Non-erasable proof or proposition dependency | Dependent erasure proof classifier |
| `LRC009` | Unsupported numeric cast or arithmetic mode | Numeric semantics matrix |
| `LRC010` | Unsupported closure representation | Closure object lowering |
| `LRC011` | Recursive data layout failure | Recursive inductive SCC layout |
| `LRC012` | FFI ABI rejection | Opaque handle ABI layer |
| `LRC013` | Unsupported polymorphic Rust generic emission | Rust generic emission policy |
| `LRC014` | Unsupported source module or import shape | Module/import lowering |

## LRC001

Unresolved typeclass dictionary. The declaration must be monomorphized,
specialized, or supported by generated dictionaries.

Example:

```lean
@[rust_export]
def unresolvedDictionary [OfNat α 0] : α :=
  OfNat.ofNat 0
```

## LRC002

Dependent runtime match. The erased index would affect runtime branch shape, so
the match must be rejected until dependent erasure can prove it safe.

Example:

```lean
@[rust_export]
def dependentRuntimeMatch (n : Nat) (v : Fin (n + 1)) : Bool :=
  match v with
  | ⟨0, _⟩ => true
  | ⟨_, _⟩ => false
```

## LRC003

Escaping captured closure. Non-escaping closure environments are supported;
returned or stored closures require first-class closure objects.

Example:

```lean
@[rust_export]
def escapingCapturedClosure (delta : UInt32) : UInt32 → UInt32 :=
  fun value => value + delta
```

## LRC004

IO or external effect. Pure `Option`, `Except`, `State`, and `Reader` effects are
separate from the controlled IO boundary.

Example:

```lean
@[rust_export]
def ioEffect (path : System.FilePath) : IO UInt32 := do
  let text ← IO.FS.readFile path
  pure text.length.toUInt32
```

## LRC005

Rust hygiene collision. Distinct Lean names collapsed to the same Rust
identifier after sanitization; rename the source declaration or binder.

Example:

```lean
@[rust_export]
def `value?` (x : UInt32) : UInt32 := x + 1

@[rust_export]
def value! (x : UInt32) : UInt32 := x + 2
```

## LRC006

Unsupported recursor or equation-compiler shape. The extractor recognized a
recursion-like elaborated form but could not prove it belongs to the current
structural or tail-recursive loop lane.

Example:

```lean
@[rust_export]
def recursorShape (n : Nat) : UInt32 :=
  Nat.recAuxOn n 0 fun _ rec => rec + 1
```

## LRC007

Unsupported Std or library constant. Add a known-lowering entry, ownership
policy, tests, and docs before allowing the constant to emit Rust.

Example:

```lean
@[rust_export]
def unsupportedStdConstant (xs : Array UInt32) : Array UInt32 :=
  xs.qsort (· < ·)
```

## LRC008

Non-erasable proof or proposition dependency. The proof/index is computationally
used or changes runtime branch shape.

Example:

```lean
@[rust_export]
def nonerasableProofDependency (p : Prop) [Decidable p] : UInt32 :=
  if h : p then
    h.recOn 1
  else
    0
```

## LRC009

Unsupported numeric cast or arithmetic mode. The declaration needs explicit
checked, wrapping, saturating, exact, or preconditioned semantics.

Example:

```lean
@[rust_export]
def unsupportedNumericMode (x y : UInt32) : UInt32 :=
  x / y
```

## LRC010

Unsupported closure representation. The closure escapes the current expression,
is stored, or requires unimplemented `Fn`/`FnMut`/`FnOnce` behavior.

Example:

```lean
structure ClosureBox where
  run : UInt32 → UInt32

@[rust_export]
def unsupportedClosureRepresentation (delta : UInt32) : ClosureBox :=
  { run := fun value => value + delta }
```

## LRC011

Recursive data layout failure. The inductive graph is not admitted by the
current owned-`Box` policy or requires mutual/nested layout support.

Example:

```lean
mutual
  inductive Expr where
    | node : Stmt → Expr

  inductive Stmt where
    | wrap : Expr → Stmt
end
```

## LRC012

FFI ABI rejection. The value cannot cross the raw ABI directly and needs an
opaque handle, destructor, or status/out-parameter lowering.

Example:

```lean
@[rust_export]
def ffiAbiRejection : Array UInt32 := #[1, 2, 3]
```

## LRC013

Unsupported polymorphic Rust generic emission. The current default lane is
monomorphization-first unless a verified generic policy admits the shape.

Example:

```lean
@[rust_export]
def unsupportedGenericEmission {α : Type} (x : α) : α := x
```

## LRC014

Unsupported source module or import shape. The declaration depends on module,
namespace, or import behavior outside the current extractor contract.

Example:

```lean
open scoped BigOperators

@[rust_export]
def unsupportedImportShape (xs : List UInt32) : UInt32 :=
  xs.foldl (· + ·) 0
```

## Extractor fallback branches

The unsupported corpus also records the extractor fallback branch that rejected
the declaration before Rust emission:

- `extract-regular-unsupported-export`: a directly exported declaration could
  not be lowered by the current extractor subset.
- `extract-mono-unsupported-export`: an auto- or manually-monomorphized export
  could not be lowered by the current extractor subset.
- `auto-helper-fixpoint-fuel`: helper extraction stopped after the bounded
  helper-fixpoint search ran out of fuel.
- `auto-generated-specs-fixpoint-fuel`: the combined helper/monomorphization
  fixpoint search stopped after exhausting its bounded fuel.

## Completion requirement

A diagnostic is complete only when the template, source-span behavior, corpus
fixture, tests, and documentation entry are all present.
