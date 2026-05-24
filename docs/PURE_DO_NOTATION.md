# Pure do-notation lowering

The extractor recognizes elaborated pure monadic code and lowers it to safe
first-order Rust control flow. The current extractor-backed direct-lane cases
cover the elaborated `Bind.bind`, `Pure.pure`, `SeqRight.seqRight`, and
`SeqLeft.seqLeft` shapes for `Option`, `Except`, `ReaderT UInt32 Id`, and
`StateM UInt32`. The broader pure-effect plan still includes the remaining
stacked state/error family:

| Effect | Rust shape | Tests |
|---|---|---|
| `Option` | elaborated `Bind.bind` / `Pure.pure` / `SeqRight.seqRight` / `SeqLeft.seqLeft` lowers to `Option` match, map, and early return | `generated.rs`, differential tests, parser/validation gates |
| `Except` | elaborated `Bind.bind` / `Pure.pure` / `SeqRight.seqRight` / `SeqLeft.seqLeft` lowers to `Result` match, map, and early return | `generated.rs`, differential tests, parser/validation gates |
| `ReaderT` | elaborated bind/pure/`*>`/`<*` lowers to explicit environment threading via `SurfaceExpr.letIn` over the applied environment argument | `generated.rs`, differential tests, parser/validation gates |
| `StateM` | elaborated bind/pure/`*>`/`<*` lowers to explicit `(value, state)` tuple threading with `SurfaceExpr.prodLit` and `SurfaceExpr.matchPattern` | `generated.rs`, differential tests, parser/validation gates |
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
- Fully applied `ReaderT ρ Id` programs lower after their final environment
  application. `MonadReader.read` becomes the applied environment value,
  `Pure.pure` becomes the inner value, `Bind.bind` becomes `let`, and
  `SeqRight.seqRight` / `SeqLeft.seqLeft` become explicit `let` sequencing.
- Fully applied `StateM σ` programs lower after their final state application.
  `MonadState.get` becomes `(state, state)`, `MonadStateOf.set` becomes
  `((), new_state)`, `Pure.pure` becomes `(value, state)`, `Bind.bind` becomes
  nested tuple destructuring with `SurfaceExpr.matchPattern`, and
  `SeqRight.seqRight` / `SeqLeft.seqLeft` thread the intermediate state through
  those same pair carriers.
- The monad constructor and instance arguments are ignored after shape
  recognition; only the concrete runtime carrier and value arguments are lowered.

Current direct-lane exported examples:

- `option_do_inc_u32` and `except_do_inc_u32` cover elaborated bind/pure.
- `option_seq_right_u32` and `except_seq_right_u32` cover elaborated `*>`.
- `option_seq_left_u32` and `except_seq_left_u32` cover elaborated `<*`.
- `reader_do_add_u32`, `reader_seq_right_u32`, and `reader_seq_left_u32`
  cover explicit `ReaderT UInt32 Id` lowering through the direct lane.
- `state_do_tick_u32`, `state_seq_right_u32`, and `state_seq_left_u32` cover
  explicit `StateM UInt32` bind and applicative sequencing through the direct
  lane.

`state_tick_u32` and the runtime pure-effect helpers still cover the admitted
state-threading model, and the direct lane now has matching source-level
`StateM` coverage for bind, `*>`, and `<*`.

`IO`, `EIO`, `Task`, mutation, and external effects do not lower through this
pure lane. They require the controlled IO boundary, and `ExceptT(StateM)`
remains outside the completed direct lane.

Completion requires implementation, tests, and documentation for this feature.
