import LeanRustCore.Extract

namespace LeanRustCore.StdExamples

open LeanRustCore.Extract

def result_map_ok_inc_u32 (x : Except UInt32 UInt32) : Except UInt32 UInt32 :=
  Except.map (fun y => y + 1) x

def list_reverse_first_or_u32 (xs : List UInt32) (fallback : UInt32) : UInt32 :=
  (List.reverse xs).foldl (fun _ x => x) fallback

def array_get_opt_u32 (xs : Array UInt32) (i : Nat) : Option UInt32 :=
  Array.get? xs i

def string_append_lean (left right : String) : String :=
  String.append left right

def string_length_chars_u32 (s : String) : Nat :=
  String.length s

def string_contains_char_lean (s : String) (c : Char) : Bool :=
  String.contains s c

end LeanRustCore.StdExamples
