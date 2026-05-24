# Generated typeclass dictionaries

The default Lean→Rust lane still specializes resolved monomorphic typeclass
instances whenever possible. When an instance cannot be erased but is still a
closed monomorphic dictionary, the backend uses explicit first-order Rust
records instead of Rust trait objects or dynamic dispatch.

Extractor-backed dictionary lowering is now wired through ordinary Lean helper
definitions:

- `apply_beq_dict_u32`
- `apply_compare_dict_u32`
- `apply_add_dict_u32`
- `apply_default_dict_u32`
- `apply_to_string_dict_u32`

The exported examples `generated_dict_beq_u32`, `generated_dict_compare_u32`,
`generated_dict_add_u32`, `generated_dict_default_u32`, and
`generated_dict_to_string_u32` lower those closed monomorphic dictionary
arguments to runtime calls that explicitly pass `BEQ_U32`, `ORD_U32`,
`ADD_U32`, `DEFAULT_U32`, and `TO_STRING_U32`.

Current limitation: only closed monomorphic dictionary arguments in this
`UInt32` slice are generated this way; unresolved or open dictionary values
remain diagnostics.

Implemented dictionary shapes:

| Lean class instance | Rust dictionary | Methods | Tests |
|---|---|---|---|
| `BEq UInt32` | `BeqDictU32` | `beq: fn(u32,u32) -> bool` | `generated_dictionary_structs_are_first_order`, `typeclass_dictionaries` |
| `Ord UInt32` | `OrdDictU32` | `compare: fn(u32,u32) -> Ordering` | runtime dictionary tests, `typeclass_dictionaries` |
| `HAdd UInt32` | `AddDictU32` | `add: fn(u32,u32) -> u32` | runtime dictionary tests, `typeclass_dictionaries` |
| `Inhabited UInt32` | `DefaultDictU32` | `default: fn() -> u32` | runtime dictionary tests, `typeclass_dictionaries` |
| `ToString UInt32` | `ToStringDictU32` | `to_string: fn(u32) -> String` | runtime dictionary tests, `typeclass_dictionaries` |

A dictionary feature is complete only when the dictionary shape, runtime helper,
Rust test, positive corpus fixture, validation-report entry, and this
documentation are all present.
