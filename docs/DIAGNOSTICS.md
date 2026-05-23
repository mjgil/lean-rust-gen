# User-facing diagnostics

Unsupported Lean must produce stable, actionable diagnostics. Every diagnostic
has a source declaration, construct kind, next feature, documentation link, and a
snapshot in the negative or unsupported corpus.

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

Diagnostics are complete only when the corresponding negative-corpus test and
documentation entry exist.
