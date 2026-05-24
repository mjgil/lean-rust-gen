# Closure conversion

The direct lane now accepts a larger source-level closure slice without
introducing trait objects, `unsafe`, or public generated closure-object types.

Supported extracted source patterns:

| Lean source shape | Lowering strategy | Example export |
|---|---|---|
| direct captured unary apply | inline let-chain | `closure_apply_capture_u32` |
| let-stored captured unary closure then apply | let-chain normalization | `stored_closure_apply_u32` |
| helper-returned captured unary closure then apply | helper beta-reduction plus let-chain normalization | `returned_closure_apply_u32` |
| helper-passed captured unary closure | higher-order helper unfolding plus let-chain normalization | `passed_closure_apply_u32` |
| let-stored captured binary closure then apply | multi-binder let-chain normalization | `stored_multi_closure_apply_u32` |
| helper-returned captured binary closure then apply | higher-order helper unfolding plus multi-binder let-chain normalization | `returned_multi_closure_apply_u32` |
| helper-passed captured binary closure | higher-order helper unfolding plus multi-binder let-chain normalization | `passed_multi_closure_apply_u32` |
| explicit environment struct closure | first-order struct field access | `closure_env_apply_add_delta_u32` |
| finite function family | defunctionalized enum plus apply function | `defun_apply_u32` |

Rejected closure classes:

- mutation-sensitive `FnMut`/`FnOnce`-like shapes remain diagnostics.
- ambient-effect closures remain in the controlled `IO` boundary task.
- escaping unsupported closure wrappers still use `LRC003` or `LRC010`.

The completion gate for this area is not just documentation. The repo now
requires the positive corpus fixtures `corpus/positive/*closure*.expected.json`,
compiled execution checks in `rust/tests/closure_lowering.rs`, exhaustive
dispatch in `rust/tests/target_interpreter.rs`, and the remaining-completion
gate in `scripts/check-remaining-completion.py`.
