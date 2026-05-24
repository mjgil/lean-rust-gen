# Pure do-notation lowering

The extractor recognizes elaborated pure monadic code and lowers it to safe
first-order Rust control flow. The current extractor-backed direct-lane cases
cover the elaborated `Bind.bind`, `Pure.pure`, `SeqRight.seqRight`, and
`SeqLeft.seqLeft` shapes for `Option` and `Except`. The broader pure-effect
plan still includes additional function-monad families:

| Effect | Rust shape | Tests |
|---|---|---|
| `Option` | elaborated `Bind.bind` / `Pure.pure` / `SeqRight.seqRight` / `SeqLeft.seqLeft` lowers to `Option` match, map, and early return | `generated.rs`, differential tests, parser/validation gates |
| `Except` | elaborated `Bind.bind` / `Pure.pure` / `SeqRight.seqRight` / `SeqLeft.seqLeft` lowers to `Result` match, map, and early return | `generated.rs`, differential tests, parser/validation gates |
| `StateM` | explicit `(value, state)` tuple runtime model exists; generalized extracted `do` lowering is still pending | runtime pure-do tests |
| `ReaderT` | explicit environment-argument runtime model exists; generalized extracted `do` lowering is still pending | runtime pure-do tests |
| `ExceptT(StateM)` | result-plus-state runtime model exists; generalized extracted `do` lowering is still pending | runtime pure-do tests |

Current extractor recognition rules:

- `Bind.bind` on `Option` lowers to `SurfaceExpr.optionBind`.
- `Bind.bind` on `Except ε` lowers to `SurfaceExpr.resultBind`.
- `Pure.pure` on `Option` lowers to `SurfaceExpr.optionSome`.
- `Pure.pure` on `Except ε` lowers to `SurfaceExpr.resultOk`.
- `SeqRight.seqRight` on `Option` lowers through `SurfaceExpr.optionBind`.
- `SeqRight.seqRight` on `Except ε` lowers through `SurfaceExpr.resultBind`.
- `SeqLeft.seqLeft` on `Option` lowers through nested `SurfaceExpr.optionBind`
  plus `SurfaceExpr.optionMap`.
- `SeqLeft.seqLeft` on `Except ε` lowers through nested
  `SurfaceExpr.resultBind` plus `SurfaceExpr.resultMapOk`.
- The monad constructor and instance arguments are ignored after shape
  recognition; only the concrete runtime carrier and value arguments are lowered.

Current direct-lane exported examples:

- `option_do_inc_u32` and `except_do_inc_u32` cover elaborated bind/pure.
- `option_seq_right_u32` and `except_seq_right_u32` cover elaborated `*>`.
- `option_seq_left_u32` and `except_seq_left_u32` cover elaborated `<*`.

`IO`, `EIO`, `Task`, mutation, and external effects do not lower through this
pure lane. They require the controlled IO boundary.

Completion requires implementation, tests, and documentation for this feature.
