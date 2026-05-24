namespace LeanRustCore.ControlledIOExamples

/-!
Controlled `IO` / `EIO` source examples for Task 54.

These declarations stay deterministic in Lean source: the whitelisted helper
operations are explicit boundary markers, and the direct extractor lowers the
exported declarations to transcript-shaped Rust outputs rather than ambient host
effects.
-/

def controlled_io_print_line (_line : String) : IO PUnit := pure ()

def controlled_io_read_env (_key : String) : IO (Option String) := pure none

def controlled_io_monotonic_time (timestamp : UInt32) : IO UInt32 := pure timestamp

def controlled_eio_print_line (_line : String) : EIO Empty PUnit := pure ()

def controlled_eio_read_env (_key : String) : EIO Empty (Option String) := pure none

def controlled_eio_monotonic_time (timestamp : UInt32) : EIO Empty UInt32 := pure timestamp

def io_boundary_transcript (line key : String) (timestamp : UInt32) : IO String := do
  let _ ← controlled_io_print_line line
  let _ ← controlled_io_read_env key
  let tick ← controlled_io_monotonic_time timestamp
  pure ("print:" ++ line ++ "|read-env:" ++ key ++ "|time:" ++ toString tick)

def eio_boundary_transcript (line key : String) (timestamp : UInt32) : EIO Empty String := do
  let _ ← controlled_eio_print_line line
  let _ ← controlled_eio_read_env key
  let tick ← controlled_eio_monotonic_time timestamp
  pure ("print:" ++ line ++ "|read-env:" ++ key ++ "|time:" ++ toString tick)

end LeanRustCore.ControlledIOExamples
