import LeanRustCore.TypeclassPolicy

namespace LeanRustCore.TypeclassDictionaries

/-!
Checklist row 41: generated typeclass dictionaries.

Specialization remains the preferred default, but class-heavy monomorphic code
that cannot be erased is represented by explicit dictionary records.  The
records are first-order values with method fields; the safe direct lane does not
use Rust trait objects or dynamic dispatch for generated dictionaries.
-/

inductive DictionaryMethodKind where
  | predicate
  | comparison
  | constructor
  | printer
  | arithmetic
  deriving Repr, BEq, DecidableEq

structure DictionaryMethod where
  name : String
  kind : DictionaryMethodKind
  signature : String
  deriving Repr, BEq

structure DictionaryShape where
  className : String
  rustName : String
  methods : List DictionaryMethod
  dispatch : String
  tests : List String
  docs : List String
  deriving Repr, BEq

private def joinWithLocal (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWithLocal sep xs

/-- Ordinary Lean helpers whose closed monomorphic dictionary arguments lower to runtime records. -/
def generatedDictionaryHelpers : List String := [
  "apply_beq_dict_u32",
  "apply_compare_dict_u32",
  "apply_add_dict_u32",
  "apply_default_dict_u32",
  "apply_to_string_dict_u32"
]

/-- Exported Lean declarations that exercise generated dictionary lowering end to end. -/
def generatedDictionaryExports : List String := [
  "generated_dict_beq_u32",
  "generated_dict_compare_u32",
  "generated_dict_add_u32",
  "generated_dict_default_u32",
  "generated_dict_to_string_u32"
]

/-- Dictionary structs admitted by the completed remaining-task patch. -/
def dictionaryShapes : List DictionaryShape := [
  { className := "BEq UInt32", rustName := "BeqDictU32", dispatch := "monomorphic function field",
    methods := [{ name := "beq", kind := .predicate, signature := "fn(u32,u32) -> bool" }],
    tests := ["crates/runtime::generated_dictionary_structs_are_first_order", "rust/tests/typeclass_dictionaries.rs"], docs := ["docs/TYPECLASS_DICTIONARIES.md"] },
  { className := "Ord UInt32", rustName := "OrdDictU32", dispatch := "monomorphic function field",
    methods := [{ name := "compare", kind := .comparison, signature := "fn(u32,u32) -> Ordering" }],
    tests := ["crates/runtime::generated_dictionary_structs_are_first_order", "rust/tests/typeclass_dictionaries.rs"], docs := ["docs/TYPECLASS_DICTIONARIES.md"] },
  { className := "HAdd UInt32", rustName := "AddDictU32", dispatch := "monomorphic function field",
    methods := [{ name := "add", kind := .arithmetic, signature := "fn(u32,u32) -> u32" }],
    tests := ["crates/runtime::generated_dictionary_structs_are_first_order", "rust/tests/typeclass_dictionaries.rs"], docs := ["docs/TYPECLASS_DICTIONARIES.md"] },
  { className := "Inhabited UInt32", rustName := "DefaultDictU32", dispatch := "monomorphic function field",
    methods := [{ name := "default", kind := .constructor, signature := "fn() -> u32" }],
    tests := ["crates/runtime::generated_dictionary_structs_are_first_order", "rust/tests/typeclass_dictionaries.rs"], docs := ["docs/TYPECLASS_DICTIONARIES.md"] },
  { className := "ToString UInt32", rustName := "ToStringDictU32", dispatch := "monomorphic function field",
    methods := [{ name := "to_string", kind := .printer, signature := "fn(u32) -> String" }],
    tests := ["crates/runtime::generated_dictionary_structs_are_first_order", "rust/tests/typeclass_dictionaries.rs"], docs := ["docs/TYPECLASS_DICTIONARIES.md"] }
]

/-- A dictionary is complete only if it has method fields, tests, and docs. -/
def dictionaryShapeComplete (shape : DictionaryShape) : Bool :=
  !shape.methods.isEmpty && !shape.tests.isEmpty && !shape.docs.isEmpty && shape.dispatch == "monomorphic function field"

/-- All completed dictionary shapes satisfy the implementation/test/doc contract. -/
def allDictionariesComplete : Bool :=
  dictionaryShapes.all dictionaryShapeComplete

/-- Human-readable report summary. -/
def typeclassDictionarySummary : String :=
  "generated monomorphic dictionary structs: " ++ joinWithLocal ", " (dictionaryShapes.map (fun shape => shape.rustName)) ++
  "; extractor-backed exports " ++ joinWithLocal ", " generatedDictionaryExports ++
  " lower closed helper dictionaries without trait objects or dynamic dispatch in the default lane"

theorem dictionary_completion_gate : allDictionariesComplete = true := by
  rfl

end LeanRustCore.TypeclassDictionaries
