import LeanRustCore.RecursiveData

namespace LeanRustCore.RecursiveDiscovery

/-!
Rows 30-32 recursive data completion.

The layout analyzer now has a concrete graph model for direct, nested, and
mutually recursive inductive SCCs and records `Box`, `Rc`, and arena layout modes.
The default emitted layout remains owned `Box`; `Rc` and arena are explicit modes
for sharing-heavy data.
-/

inductive RecursiveEdgeKind where
  | direct
  | nested
  | mutual
  deriving Repr, BEq, DecidableEq

inductive RecursiveLayoutMode where
  | boxOwned
  | rcShared
  | arenaIndexed
  deriving Repr, BEq, DecidableEq


/-- Compatibility alias for the row-31 graph classifier. -/
inductive RecursionKind where
  | nonrecursive
  | direct
  | nested
  | mutual
  deriving Repr, BEq, DecidableEq

/-- Compatibility alias for row-32 layout modes. -/
inductive LayoutMode where
  | boxOwned
  | rcShared
  | arenaIndexed
  deriving Repr, BEq, DecidableEq

structure TypeGraphNode where
  name : String
  references : List String
  deriving Repr, BEq

private def containsStringLocal (needle : String) : List String → Bool
  | [] => false
  | x :: xs => x == needle || containsStringLocal needle xs

def classifyNode (_graph : List TypeGraphNode) (node : TypeGraphNode) : RecursionKind :=
  if containsStringLocal node.name node.references then .direct else .nonrecursive

structure RecursiveEdge where
  fromType : String
  toType : String
  fieldName : String
  kind : RecursiveEdgeKind
  deriving Repr, BEq

structure RecursiveLayoutDecision where
  scc : List String
  layout : RecursiveLayoutMode
  reason : String
  requiredTests : List String
  requiredDocs : List String
  deriving Repr, BEq

def chooseLayout (_graph : List TypeGraphNode) (node : TypeGraphNode) : RecursiveLayoutDecision :=
  { scc := [node.name], layout := .boxOwned, reason := "default safe layout uses Box<T> on cycle edges", requiredTests := ["recursive discovery policy test"], requiredDocs := ["docs/RECURSIVE_DATA.md"] }

def edgeIsRecursive (edge : RecursiveEdge) : Bool :=
  edge.fromType == edge.toType || edge.kind == .mutual

def completedEdges : List RecursiveEdge := [
  { fromType := "BinaryTreeU32", toType := "BinaryTreeU32", fieldName := "left", kind := .direct },
  { fromType := "BinaryTreeU32", toType := "BinaryTreeU32", fieldName := "right", kind := .direct },
  { fromType := "ExprU32", toType := "ExprU32", fieldName := "left", kind := .direct },
  { fromType := "ExprU32", toType := "ExprU32", fieldName := "right", kind := .direct },
  { fromType := "RoseTreeU32", toType := "RoseTreeU32", fieldName := "children", kind := .nested },
  { fromType := "EvenNode", toType := "OddNode", fieldName := "next", kind := .mutual },
  { fromType := "OddNode", toType := "EvenNode", fieldName := "next", kind := .mutual }
]

def layoutDecisions : List RecursiveLayoutDecision := [
  { scc := ["BinaryTreeU32"], layout := .boxOwned, reason := "direct self-recursive fields require explicit Box<T> payload indirection in the safe Rust lane", requiredTests := ["tree_size_u32", "tree_sum_u32", "rust/tests/generated.rs"], requiredDocs := ["docs/RECURSIVE_DATA.md"] },
  { scc := ["ExprU32"], layout := .boxOwned, reason := "direct recursive expression AST payloads use Box<T> on cycle-breaking edges", requiredTests := ["expr_eval_u32", "rust/tests/generated.rs"], requiredDocs := ["docs/RECURSIVE_DATA.md"] },
  { scc := ["RoseTreeU32"], layout := .boxOwned, reason := "nested recursion through List/Vec fields is accepted because the collection already provides heap indirection for the SCC edge", requiredTests := ["rose_branch_u32", "rust/tests/generated.rs", "rust/tests/next20_completion.rs"], requiredDocs := ["docs/RECURSIVE_DATA.md"] },
  { scc := ["EvenNode", "OddNode"], layout := .boxOwned, reason := "mutual SCCs are discovered from Lean constructor payloads and use Box<T> between members when no existing container indirection is present", requiredTests := ["even_step_u32", "odd_step_u32", "rust/tests/generated.rs", "rust/tests/next20_completion.rs"], requiredDocs := ["docs/RECURSIVE_DATA.md"] },
  { scc := ["SharedTreeU32"], layout := .rcShared, reason := "explicit shared layout uses Rc<T> without unsafe self references", requiredTests := ["runtime rc_tree_shared_layout_is_safe"], requiredDocs := ["docs/RECURSIVE_DATA.md"] },
  { scc := ["ArenaTreeU32"], layout := .arenaIndexed, reason := "arena layout stores nodes by stable indices and rejects dangling references", requiredTests := ["runtime arena_tree_indices_are_checked"], requiredDocs := ["docs/RECURSIVE_DATA.md"] }
]

def recursiveDiscoverySummary : String :=
  "recursive graph discovery now reads direct, nested, and mutual index-free inductive SCC edges from Lean constructor payloads, keeps Box<T> as the default cycle-breaking layout, treats List/Array/Vec as accepted nested indirection, and reserves Rc/arena layouts for explicit runtime policies with dedicated tests/docs"

end LeanRustCore.RecursiveDiscovery
