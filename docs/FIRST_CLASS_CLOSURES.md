# First-class closure objects

Non-mutating monomorphic closures can now be represented as ordinary Rust values.
The direct lane uses enum/object representations such as `U32ClosureObject` and
`StoredClosureU32`, not `unsafe`, trait objects, or dynamic dispatch.

Supported shapes:

| Shape | Runtime representation | Status |
|---|---|---|
| returned closure | `StoredClosureU32` | supported |
| stored closure | owned struct field | supported |
| composed closure | `U32ClosureObject::Compose` | supported |
| captured delta closure | `U32ClosureObject::AddDelta` | supported |
| `FnMut`/`FnOnce` mutation | diagnostic | unsupported by default |

Source-level extracted closures now have a second layer on top of that runtime
support. Stored, returned, passed, and multi-argument captured closures are
accepted when they normalize to first-order let chains before Rust emission:

- `stored_closure_apply_u32`
- `returned_closure_apply_u32`
- `passed_closure_apply_u32`
- `stored_multi_closure_apply_u32`
- `returned_multi_closure_apply_u32`
- `passed_multi_closure_apply_u32`

`docs/CLOSURE_CONVERSION.md` records the lowering strategy per source closure
class. Completion for this feature now requires the runtime closure-object
tests, the generated closure-lowering tests, target-interpreter coverage, and
the remaining-completion corpus gate.
