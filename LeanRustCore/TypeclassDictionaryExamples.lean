import LeanRustCore.Extract

namespace LeanRustCore.Examples

open LeanRustCore
open LeanRustCore.Extract

/-- Explicit monomorphic dictionary helper used by the generated-dictionary lane. -/
def apply_beq_dict_u32 (dict : BEq UInt32) (a b : UInt32) : Bool :=
  @BEq.beq UInt32 dict a b

/-- Explicit monomorphic dictionary helper used by the generated-dictionary lane. -/
def apply_compare_dict_u32 (dict : Ord UInt32) (a b : UInt32) : Ordering :=
  @Ord.compare UInt32 dict a b

/-- Explicit monomorphic dictionary helper used by the generated-dictionary lane. -/
def apply_add_dict_u32 (dict : HAdd UInt32 UInt32 UInt32) (a b : UInt32) : UInt32 :=
  @HAdd.hAdd UInt32 UInt32 UInt32 dict a b

/-- Explicit monomorphic dictionary helper used by the generated-dictionary lane. -/
def apply_default_dict_u32 (dict : Inhabited UInt32) : UInt32 :=
  @Inhabited.default UInt32 dict

/-- Explicit monomorphic dictionary helper used by the generated-dictionary lane. -/
def apply_to_string_dict_u32 (dict : ToString UInt32) (x : UInt32) : String :=
  @ToString.toString UInt32 dict x

def beq_dict_u32_inst : BEq UInt32 := inferInstance
def compare_dict_u32_inst : Ord UInt32 := inferInstance
def add_dict_u32_inst : HAdd UInt32 UInt32 UInt32 := inferInstance
def default_dict_u32_inst : Inhabited UInt32 := inferInstance
def to_string_dict_u32_inst : ToString UInt32 := inferInstance

end LeanRustCore.Examples
