# Pure do-notation lowering

The extractor recognizes elaborated pure monadic code and lowers it to safe
first-order Rust control flow. The currently extractor-backed direct-lane cases
are the elaborated `Bind.bind` / `Pure.pure` shapes for `Option` and `Except`.
The broader pure-effect plan still includes additional function-monad families:

| Effect | Rust shape | Tests |
|---|---|---|
| `Option` | elaborated `Bind.bind` / `Pure.pure` lowers to `Option` match / early return | `generated.rs`, differential tests, parser/validation gates |
| `Except` | elaborated `Bind.bind` / `Pure.pure` lowers to `Result` match / early return | `generated.rs`, differential tests, parser/validation gates |
| `StateM` | explicit `(value, state)` tuple runtime model exists; generalized extracted `do` lowering is still pending | runtime pure-do tests |
| `ReaderT` | explicit environment-argument runtime model exists; generalized extracted `do` lowering is still pending | runtime pure-do tests |
| `ExceptT(StateM)` | result-plus-state runtime model exists; generalized extracted `do` lowering is still pending | runtime pure-do tests |

Current extractor recognition rules:

- `Bind.bind` on `Option` lowers to `SurfaceExpr.optionBind`.
- `Bind.bind` on `Except ε` lowers to `SurfaceExpr.resultBind`.
- `Pure.pure` on `Option` lowers to `SurfaceExpr.optionSome`.
- `Pure.pure` on `Except ε` lowers to `SurfaceExpr.resultOk`.
- The monad constructor and instance arguments are ignored after shape
  recognition; only the concrete runtime carrier and value arguments are lowered.

`IO`, `EIO`, `Task`, mutation, and external effects do not lower through this
pure lane. They require the controlled IO boundary.

Completion requires implementation, tests, and documentation for this feature.
