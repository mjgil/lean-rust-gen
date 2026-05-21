import LeanRustCore.Surface

namespace LeanRustCore

/-!
Rust identifier hygiene for the direct Lean → Rust emitter.

The extractor stores source-facing names in `SurfaceExpr`; this module is the
single place that turns those names into Rust identifiers and checks that the
translation does not introduce collisions.
-/

private def joinWithLocal (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWithLocal sep xs

private def asciiLower : List Char := "abcdefghijklmnopqrstuvwxyz".toList
private def asciiUpper : List Char := "ABCDEFGHIJKLMNOPQRSTUVWXYZ".toList
private def asciiDigits : List Char := "0123456789".toList

private def containsChar : List Char → Char → Bool
  | [], _ => false
  | x :: xs, c => x == c || containsChar xs c

private def isAsciiAlpha (c : Char) : Bool :=
  containsChar asciiLower c || containsChar asciiUpper c

private def isAsciiDigit (c : Char) : Bool :=
  containsChar asciiDigits c

private def isRustIdentStart (c : Char) : Bool :=
  isAsciiAlpha c || c == '_'

private def isRustIdentContinue (c : Char) : Bool :=
  isRustIdentStart c || isAsciiDigit c

private def cleanIdentChars : List Char → List Char
  | [] => []
  | c :: cs => (if isRustIdentContinue c then c else '_') :: cleanIdentChars cs

private def startsWithValidIdentChar (s : String) : Bool :=
  match s.toList with
  | [] => false
  | c :: _ => isRustIdentStart c

private def rustKeywords : List String := [
  "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum",
  "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod",
  "move", "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super",
  "trait", "true", "type", "unsafe", "use", "where", "while", "abstract", "become", "box",
  "do", "final", "macro", "override", "priv", "try", "typeof", "unsized", "virtual", "yield"
]

private def rawIdentForbidden : List String := ["crate", "self", "super", "Self", "true", "false"]

private def containsStringLocal : List String → String → Bool
  | [], _ => false
  | x :: xs, s => x == s || containsStringLocal xs s

/-- Sanitize an arbitrary source string into a valid Rust identifier. -/
def sanitizeRustIdent (fallback : String) (source : String) : String :=
  let trimmed := if source == "" || source == "_" then fallback else source
  let cleaned := String.mk (cleanIdentChars trimmed.toList)
  let withStart := if startsWithValidIdentChar cleaned then cleaned else "_" ++ cleaned
  if containsStringLocal rawIdentForbidden withStart then
    "_" ++ withStart
  else if containsStringLocal rustKeywords withStart then
    "r#" ++ withStart
  else
    withStart

/-- Rust value/function/local identifier spelling. -/
def rustValueIdent (fallback source : String) : String :=
  sanitizeRustIdent fallback source

/-- Rust field identifier spelling. -/
def rustFieldIdent (source : String) : String :=
  sanitizeRustIdent "field" source

private def upperAscii : Char → Char
  | 'a' => 'A' | 'b' => 'B' | 'c' => 'C' | 'd' => 'D' | 'e' => 'E' | 'f' => 'F'
  | 'g' => 'G' | 'h' => 'H' | 'i' => 'I' | 'j' => 'J' | 'k' => 'K' | 'l' => 'L'
  | 'm' => 'M' | 'n' => 'N' | 'o' => 'O' | 'p' => 'P' | 'q' => 'Q' | 'r' => 'R'
  | 's' => 'S' | 't' => 'T' | 'u' => 'U' | 'v' => 'V' | 'w' => 'W' | 'x' => 'X'
  | 'y' => 'Y' | 'z' => 'Z'
  | c => c

private def lowerAscii : Char → Char
  | 'A' => 'a' | 'B' => 'b' | 'C' => 'c' | 'D' => 'd' | 'E' => 'e' | 'F' => 'f'
  | 'G' => 'g' | 'H' => 'h' | 'I' => 'i' | 'J' => 'j' | 'K' => 'k' | 'L' => 'l'
  | 'M' => 'm' | 'N' => 'n' | 'O' => 'o' | 'P' => 'p' | 'Q' => 'q' | 'R' => 'r'
  | 'S' => 's' | 'T' => 't' | 'U' => 'u' | 'V' => 'v' | 'W' => 'w' | 'X' => 'x'
  | 'Y' => 'y' | 'Z' => 'z'
  | c => c

private def capitalizeWord (s : String) : String :=
  match s.toList with
  | [] => ""
  | c :: cs => String.mk (upperAscii c :: cs.map lowerAscii)

private def pushWord (current : List Char) (words : List String) : List String :=
  match current with
  | [] => words
  | chars => words ++ [String.mk chars]

private partial def splitWordsAux (chars : List Char) (current : List Char) (words : List String) : List String :=
  match chars with
  | [] => pushWord current words
  | c :: rest =>
      if isRustIdentContinue c && c != '_' then
        splitWordsAux rest (current ++ [c]) words
      else
        splitWordsAux rest [] (pushWord current words)

private def upperCamel (fallback source : String) : String :=
  let words := splitWordsAux source.toList [] []
  let rendered := joinWithLocal "" (words.map capitalizeWord)
  let base := if rendered == "" then fallback else rendered
  sanitizeRustIdent fallback base

/-- Rust type identifier spelling. -/
def rustTypeIdent (source : String) : String :=
  upperCamel "GeneratedType" source

/-- Rust enum variant spelling. -/
def rustVariantIdent (source : String) : String :=
  upperCamel "Variant" source

/-- Backward-compatible alias used by differential fixtures. -/
def rustVariantName (variant : String) : String :=
  rustVariantIdent variant

structure RustHygieneIssue where
  context : String
  source : String
  rustName : String
  detail : String
  deriving Repr, BEq

private def issueToString (i : RustHygieneIssue) : String :=
  i.context ++ ": " ++ i.detail ++ " (`" ++ i.source ++ "` → `" ++ i.rustName ++ "`)"

private def lookupRendered (rendered : String) : List (String × String) → Option String
  | [] => none
  | (source, rustName) :: rest => if rustName == rendered then some source else lookupRendered rendered rest

private partial def detectNameCollisionsAux (context : String) (seen : List (String × String)) : List (String × String) → List RustHygieneIssue
  | [] => []
  | (source, rustName) :: rest =>
      let tail := detectNameCollisionsAux context ((source, rustName) :: seen) rest
      match lookupRendered rustName seen with
      | none => tail
      | some previous =>
          { context := context,
            source := source,
            rustName := rustName,
            detail := "identifier collision after Rust hygiene with `" ++ previous ++ "`" } :: tail

private def detectNameCollisions (context : String) (items : List (String × String)) : List RustHygieneIssue :=
  detectNameCollisionsAux context [] items

private def typeNameEntries (types : List String) : List (String × String) :=
  types.map (fun name => (name, rustTypeIdent name))

private def valueNameEntries (fallback : String) (names : List String) : List (String × String) :=
  names.map (fun name => (name, rustValueIdent fallback name))

private def fieldNameEntries (fields : List RArg) : List (String × String) :=
  fields.map (fun field => (field.1, rustFieldIdent field.1))

private def variantNameEntries (variants : List (String × List RType)) : List (String × String) :=
  variants.map (fun variant => (variant.1, rustVariantIdent variant.1))

partial def surfaceBinders : SurfaceExpr → List String
  | .var _ => []
  | .litUnit => []
  | .litBool _ => []
  | .litU32 _ => []
  | .litU64 _ => []
  | .litI32 _ => []
  | .litI64 _ => []
  | .litChar _ => []
  | .litString _ => []
  | .letIn name value body => name :: surfaceBinders value ++ surfaceBinders body
  | .ite c a b => surfaceBinders c ++ surfaceBinders a ++ surfaceBinders b
  | .matchBool c a b => surfaceBinders c ++ surfaceBinders a ++ surfaceBinders b
  | .matchOption target noneCase someName someCase => surfaceBinders target ++ surfaceBinders noneCase ++ (someName :: surfaceBinders someCase)
  | .matchEnum _ target branches =>
      surfaceBinders target ++ branches.bind (fun branch => branch.2.1 ++ surfaceBinders branch.2.2)
  | .not a => surfaceBinders a
  | .and a b => surfaceBinders a ++ surfaceBinders b
  | .or a b => surfaceBinders a ++ surfaceBinders b
  | .eq _ a b => surfaceBinders a ++ surfaceBinders b
  | .lt _ a b => surfaceBinders a ++ surfaceBinders b
  | .le _ a b => surfaceBinders a ++ surfaceBinders b
  | .gt _ a b => surfaceBinders a ++ surfaceBinders b
  | .ge _ a b => surfaceBinders a ++ surfaceBinders b
  | .add _ a b => surfaceBinders a ++ surfaceBinders b
  | .sub _ a b => surfaceBinders a ++ surfaceBinders b
  | .mul _ a b => surfaceBinders a ++ surfaceBinders b
  | .min _ a b => surfaceBinders a ++ surfaceBinders b
  | .max _ a b => surfaceBinders a ++ surfaceBinders b
  | .optionNone _ => []
  | .optionSome a => surfaceBinders a
  | .resultOk _ a => surfaceBinders a
  | .resultErr _ e => surfaceBinders e
  | .structLit _ fields => fields.bind (fun field => surfaceBinders field.2)
  | .field target _ => surfaceBinders target
  | .enumVariant _ _ payload => payload.bind surfaceBinders
  | .call _ _ _ args => args.bind surfaceBinders
  | .callValue fn _ _ arg => surfaceBinders fn ++ surfaceBinders arg
  | .listMap binder _ _ target body => binder :: surfaceBinders target ++ surfaceBinders body
  | .listFilter binder _ target predicate => binder :: surfaceBinders target ++ surfaceBinders predicate
  | .listFoldl accName elemName _ _ init target body => accName :: elemName :: surfaceBinders init ++ surfaceBinders target ++ surfaceBinders body
  | .listFoldr elemName accName _ _ target init body => elemName :: accName :: surfaceBinders target ++ surfaceBinders init ++ surfaceBinders body
  | .listAny binder _ target predicate => binder :: surfaceBinders target ++ surfaceBinders predicate
  | .listAll binder _ target predicate => binder :: surfaceBinders target ++ surfaceBinders predicate
  | .arrayMap binder _ _ target body => binder :: surfaceBinders target ++ surfaceBinders body
  | .arrayFoldl accName elemName _ _ init target body => accName :: elemName :: surfaceBinders init ++ surfaceBinders target ++ surfaceBinders body
  | .optionMap binder _ _ target body => binder :: surfaceBinders target ++ surfaceBinders body
  | .optionBind binder _ _ target body => binder :: surfaceBinders target ++ surfaceBinders body
  | .resultMapOk binder _ _ _ target body => binder :: surfaceBinders target ++ surfaceBinders body
  | .resultBind binder _ _ _ target body => binder :: surfaceBinders target ++ surfaceBinders body
  | .subtypeErase _ value => surfaceBinders value
  | .subtypeVal _ value => surfaceBinders value
  | .finCheck _ value => surfaceBinders value
  | .finVal _ value => surfaceBinders value
  | .vectorCheck _ _ value => surfaceBinders value
  | .listMap binder _ _ target body =>
      surfaceBinders target ++ (binder :: surfaceBinders body)
  | .listFoldl accName elemName _ _ init target body =>
      surfaceBinders init ++ surfaceBinders target ++ (accName :: elemName :: surfaceBinders body)
  | .natFold idxName accName _ init n body =>
      surfaceBinders init ++ surfaceBinders n ++ (idxName :: accName :: surfaceBinders body)

private def validateStructHygiene (s : SurfaceStruct) : List RustHygieneIssue :=
  detectNameCollisions ("struct " ++ s.name ++ " fields") (fieldNameEntries s.fields)

private def validateEnumHygiene (e : SurfaceEnum) : List RustHygieneIssue :=
  detectNameCollisions ("enum " ++ e.name ++ " variants") (variantNameEntries e.variants)

private def validateFunctionHygiene (f : SurfaceFun) : List RustHygieneIssue :=
  detectNameCollisions ("function " ++ f.name ++ " arguments and local binders")
    (valueNameEntries "value" (f.args.map (fun arg => arg.1) ++ surfaceBinders f.body))

/-- Find Rust identifier collisions introduced by sanitization/case conversion. -/
def surfaceModuleHygieneIssues (m : SurfaceModule) : List RustHygieneIssue :=
  detectNameCollisions "generated type declarations" (typeNameEntries (m.structs.map (fun s => s.name) ++ m.enums.map (fun e => e.name))) ++
  detectNameCollisions "generated function declarations" (valueNameEntries "generated" (m.functions.map (fun f => f.name))) ++
  m.structs.bind validateStructHygiene ++
  m.enums.bind validateEnumHygiene ++
  m.functions.bind validateFunctionHygiene

/-- Reject a generated surface module if Rust identifier hygiene would collapse distinct names. -/
def validateSurfaceModuleHygiene (m : SurfaceModule) : Except CompatibilityReport SurfaceModule :=
  match surfaceModuleHygieneIssues m with
  | [] => pure m
  | issue :: _ => throw { code := .unsupportedDeclaration, detail := issueToString issue }

/-- Human-readable summary for validation reports. -/
def rustHygieneSummary : String :=
  "Rust identifiers are sanitized for ASCII Rust syntax, keywords are escaped or prefixed, type/variant names use UpperCamelCase, and generated modules are checked for post-sanitization collisions before emission"

end LeanRustCore
