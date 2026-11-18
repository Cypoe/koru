// Koru Standard Library: grammar — the annotation-dialect catalog.
//
// C3 ruling (2026-11-17): dialect/entry/env/residue are `kind:` tags on
// `std/spec:spec` rows, not a tor family — one row vocabulary, per-kind
// judges, specialized walkers hoisted on top. This file is the dialect
// CONTENT the judges consume: which `[...]` entries a consumer claims,
// how their arguments are judged, which env resolves the leaves, and
// what happens to everything left over.
//
// A dialect is data plus a shared judge, never a second grammar —
// `src/expression_parser.zig` stays the single referent for expression
// shape, `comptime_eval.evalAnnotationEntry`/`evalAnnotationExpr` the
// single evaluator. An entry judged `"args": "expr"` is parsed by
// `annotation_parser.parseCallExpr` — `.expr` (one whole ast.Expression)
// or `.raw` (verbatim residue) per argument. Symbol resolution is never
// in the catalog: a leaf identifier names whatever the judge's provider
// binds it to (flags, env, command).
//
// Residue is a first-class contract: an annotation no dialect claims is
// legal; a `.raw` argument inside a claimed entry is the judge's
// keep-or-refuse call, declared per dialect. Parsing is a service,
// never a gate.
//
// Row shape (spec sites; kind selects the judge's reading):
//
//   ~std/spec:spec { "kind": "dialect", "name": "build",
//                     "reads": ["build"] }
//   ~std/spec:spec { "kind": "entry", "dialect": "build", "name": "build",
//                     "args": "expr", "eval": "flags" }
//   ~std/spec:spec { "kind": "env", "dialect": "build", "leaf": "flag" }
//   ~std/spec:spec { "kind": "residue", "dialect": "build",
//                     "unknown-entry": "keep", "raw-arg": "keep" }
//
// `args` vocabulary:
//   "expr"    — each argument judged by the language's own grammar
//   "string*" — positional atoms, the legacy parseCall shape
//   "opaque"  — entry claimed by name only; argument text never judged
//
// `eval` names the provider env the judge consults for leaves; "flags"
// is the compiler-flag provider chain (flag atoms, `x == "v"` as
// flag `x=v`, and/or/not) — the same vocabulary the import/item gates
// evaluate. env rows declare leaf -> binding-source tables for dialects
// that bind leaves elsewhere.
//
// A user program defines a dialect by writing the same kind-rows in its
// own tree — the judge harvests `std/spec:spec` sites from the whole
// program AST (module_decl items included), so a dialect declared by
// the program overrides or extends a std dialect by merge.

~import std/spec

// The std `build` dialect: `[...]` entries judged by build.kz's
// matchesFlags — the conditional-compilation judge for requires,
// variants, and config sites.
~std/spec:spec { "kind": "dialect", "name": "build", "reads": ["build"] }
~std/spec:spec { "kind": "entry", "dialect": "build", "name": "build", "args": "expr", "eval": "flags", "residue": "keep" }
~std/spec:spec { "kind": "residue", "dialect": "build", "unknown-entry": "keep", "raw-arg": "keep" }
