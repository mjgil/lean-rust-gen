# Controlled IO boundary

The default generated Rust lane is pure. Task 54 closes the narrow admitted
effect slice by lowering whitelisted Lean `IO` / `EIO` examples to deterministic
transcript-shaped Rust outputs instead of host effects.

Whitelisted operations:

| Operation | Rust shape | Deterministic test |
|---|---|---|
| print line | append `print:<line>` to transcript | `controlled_io_boundary_is_transcript_based` |
| read env | append `read-env:<key>` to transcript, using supplied environment inputs only | runtime test |
| monotonic time | append supplied deterministic timestamp | runtime test |

Extractor-backed Lean examples:

```lean
@[rust_export]
def io_boundary_transcript (line key : String) (timestamp : UInt32) : IO String := do
  let _ <- controlled_io_print_line line
  let _ <- controlled_io_read_env key
  let tick <- controlled_io_monotonic_time timestamp
  pure ("print:" ++ line ++ "|read-env:" ++ key ++ "|time:" ++ toString tick)
```

```lean
@[rust_export]
def eio_boundary_transcript (line key : String) (timestamp : UInt32) : EIO Empty String := do
  let _ <- controlled_eio_print_line line
  let _ <- controlled_eio_read_env key
  let tick <- controlled_eio_monotonic_time timestamp
  pure ("print:" ++ line ++ "|read-env:" ++ key ++ "|time:" ++ toString tick)
```

Generated Rust shape:

- `io_boundary_transcript(String, String, u32) -> String`
- `eio_boundary_transcript(String, String, u32) -> String`

Both exports materialize the deterministic transcript directly in the generated
Rust lane. The runtime crate still keeps `ControlledIoProgram` as the explicit
boundary model used by the runtime-only tests and documentation.

Arbitrary `IO`, `EIO`, `Task`, ambient process environment reads, mutation,
`IO.FS.readFile`, and other external effects remain rejected with `LRC004`
unless a future effect-specific boundary admits them with tests and safety
documentation.

Completion now requires:

- extractor-backed `IO` / `EIO` examples
- positive corpus fixtures for the admitted boundary exports
- generated, differential, interpreter, and release-gate coverage
- documentation showing both the Lean source and the transcript-shaped Rust API
