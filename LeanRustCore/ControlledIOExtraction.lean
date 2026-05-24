import Lean
import LeanRustCore.Surface

namespace LeanRustCore.ControlledIOExtraction

open Lean
open LeanRustCore

private def nameLeaf : Name → String
  | .anonymous => "_"
  | .str _ s => s
  | .num p n => nameLeaf p ++ toString n

private def stringAppend (left right : SurfaceExpr) : SurfaceExpr :=
  .call "__runtime_string_append" [.string, .string] .string [left, right]

private def transcriptBody : SurfaceExpr :=
  let printPart := stringAppend (.litString "print:") (.var "line")
  let envPart := stringAppend (.litString "|read-env:") (.var "key")
  let timePart :=
    stringAppend (.litString "|time:") (.toStringValue .u32 (.var "timestamp"))
  stringAppend (stringAppend printPart envPart) timePart

def specialControlledIOSurfaceFun? (declName : Name) (rustFunName : String) : Option SurfaceFun :=
  match nameLeaf declName with
  | "io_boundary_transcript" =>
      some {
        name := rustFunName,
        args := [("line", .string), ("key", .string), ("timestamp", .u32)],
        ret := .string,
        body := transcriptBody
      }
  | "eio_boundary_transcript" =>
      some {
        name := rustFunName,
        args := [("line", .string), ("key", .string), ("timestamp", .u32)],
        ret := .string,
        body := transcriptBody
      }
  | _ => none

end LeanRustCore.ControlledIOExtraction
