# Pure do-notation lowering

The extractor recognizes elaborated pure monadic code and lowers it to safe
first-order Rust control flow. The supported families are pure only:

| Effect | Rust shape | Tests |
|---|---|---|
| `Option` | `Option` match / early return | runtime pure-do tests |
| `Except` | `Result` match / early return | runtime pure-do tests |
| `StateM` | explicit `(value, state)` tuple | runtime pure-do tests |
| `ReaderT` | explicit environment argument | runtime pure-do tests |
| `ExceptT(StateM)` | `Result` plus state tuple | runtime pure-do tests |

`IO`, `EIO`, `Task`, mutation, and external effects do not lower through this
pure lane. They require the controlled IO boundary.

Completion requires implementation, tests, and documentation for this feature.
