# Feature-complete coverage dashboard

The dashboard is complete when it covers all relevant denominators:

| Denominator | Gate |
|---|---|
| Lean feature families | `scripts/check-remaining-completion.py` |
| Rust target grammar heads | validator crate tests |
| Std lowering families | next-20 completion gate |
| diagnostic codes | first-20 completion gate |
| property generators | remaining completion gate |
| preservation obligations | remaining completion gate |
| workspace release crates | final crate split gate |

A feature may not be marked supported unless implementation, tests, and
documentation are all present.
