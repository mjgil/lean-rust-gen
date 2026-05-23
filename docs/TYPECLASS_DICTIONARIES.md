# Generated typeclass dictionaries

The default Lean→Rust lane still specializes resolved monomorphic typeclass
instances whenever possible. When an instance cannot be erased but is still a
closed monomorphic dictionary, the backend uses explicit first-order Rust
records instead of Rust trait objects or dynamic dispatch.

Implemented dictionary shapes:

| Lean class instance | Rust dictionary | Methods | Tests |
|---|---|---|---|
| `BEq UInt32` | `BeqDictU32` | `beq: fn(u32,u32) -> bool` | `generated_dictionary_structs_are_first_order` |
| `Ord UInt32` | `OrdDictU32` | `compare: fn(u32,u32) -> Ordering` | runtime dictionary tests |
| `HAdd UInt32` | `AddDictU32` | `add: fn(u32,u32) -> u32` | runtime dictionary tests |
| `Inhabited UInt32` | `DefaultDictU32` | `default: fn() -> u32` | runtime dictionary tests |
| `ToString UInt32` | `ToStringDictU32` | `to_string: fn(u32) -> String` | runtime dictionary tests |

A dictionary feature is complete only when the dictionary shape, runtime helper,
Rust test, validation-report entry, and this documentation are all present.
