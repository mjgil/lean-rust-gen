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

Completion requires runtime tests for returned/stored/composed closures and docs
for the ownership and mutation policy.
