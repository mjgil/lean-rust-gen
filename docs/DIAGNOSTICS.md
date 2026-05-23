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

## LRC002

Dependent runtime match. The erased index would affect runtime branch shape, so
the match must be rejected until dependent erasure can prove it safe.

## LRC003

Escaping captured closure. Non-escaping closure environments are supported;
returned or stored closures require first-class closure objects.

## LRC004

IO or external effect. Pure `Option`, `Except`, `State`, and `Reader` effects are
separate from the controlled IO boundary.

## LRC005

Rust hygiene collision. Distinct Lean names collapsed to the same Rust
identifier after sanitization; rename the source declaration or binder.

## LRC006

Unsupported recursor or equation-compiler shape. The extractor recognized a
recursion-like elaborated form but could not prove it belongs to the current
structural or tail-recursive loop lane.

## LRC007

Unsupported Std or library constant. Add a known-lowering entry, ownership
policy, tests, and docs before allowing the constant to emit Rust.

## LRC008

Non-erasable proof or proposition dependency. The proof/index is computationally
used or changes runtime branch shape.

## LRC009

Unsupported numeric cast or arithmetic mode. The declaration needs explicit
checked, wrapping, saturating, exact, or preconditioned semantics.

## LRC010

Unsupported closure representation. The closure escapes the current expression,
is stored, or requires unimplemented `Fn`/`FnMut`/`FnOnce` behavior.

## LRC011

Recursive data layout failure. The inductive graph is not admitted by the
current owned-`Box` policy or requires mutual/nested layout support.

## LRC012

FFI ABI rejection. The value cannot cross the raw ABI directly and needs an
opaque handle, destructor, or status/out-parameter lowering.

## LRC013

Unsupported polymorphic Rust generic emission. The current default lane is
monomorphization-first unless a verified generic policy admits the shape.

## LRC014

Unsupported source module or import shape. The declaration depends on module,
namespace, or import behavior outside the current extractor contract.

## Completion requirement

A diagnostic is complete only when the template, source-span behavior, corpus
fixture, tests, and documentation entry are all present.
