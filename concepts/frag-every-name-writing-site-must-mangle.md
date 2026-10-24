---
type: belief
id: frag-every-name-writing-site-must-mangle
provenance: a commissioned cell in intranquil-domain (WO-002, 2026-09) omitted `pitch-offset` at a .k call site and the injected default emitted `.pitch-offset = null` — a Zig syntax error. The same defect existed in four places at once; pinned as 400_194.
ts: 2026-09-22
---

# A declared name is not a Zig identifier — every site that writes one into emitted code must mangle, and the rule had four copies, all wrong the same way

Kebab is not an edge case in Koru — it is the house spelling (`pitch-offset`,
`set-color`, `note-region`). `.k`-parsed names get normalized at parse time,
but **`.kz` host declarations do not**: a tor's input-shape field name reaches
the emitter still carrying `-`, and any site that writes `field.name` into
emitted Zig without mangling produces a syntax error in code the author never
wrote.

The shape that made this expensive: the OPTIONAL PARAMETER INJECTION rule
(omitted `?T` fills `null`) existed in **four separate emission paths** —
the top-level emitArgs, two impl-flow twins in emitter_helpers, and the
subflow path in visitor_emitter — each an independently maintained copy, and
every one wrote `field.name` verbatim while the explicit-arg path right
beside it correctly used `writeBranchName`. Explicit `pitch-offset: 48`
compiled; omitting it broke. The asymmetry is what made it a bug rather than
a convention: the corpus exercised kebab optionals *provided* everywhere,
but never *omitted* — `400_180` pinned the injection with a non-hyphenated
name, so the cross product of two independently-covered features was the
hole.

The ruling: **name-writing is a mangle-or-die site, not a borrow-the-string
site.** `writeBranchName` (kebab→snake, keyword-escapes) is the single
spelling for any declared name reaching emitted Zig — field names, branch
names, arg names — and a new emission path that re-implements an existing
rule (like the four injection copies) inherits every defect the original
had plus whatever it adds itself. The adjacent latent class is flagged and now
measured red: `bc.fields` loops (~16 sites) emit `.{ .field-name = }`
branch-payload literals with the same verbatim write, and 230_020 exercises
it — `| found { pos-tempo: i32 }` constructed by `=>` emits
`.{ .pos-tempo = 120 }`, a Zig syntax error, pinned aspirational until the
payload-field sites join the one-spelling invariant.

2026-09-23: the latent class is dead — 230_020 green. Every `bc.fields` /
struct-literal / record-shape name write now goes through `writeBranchName`
or `appendBranchName` (emitter_helpers ×12, continuation_codegen ×4), and the
two field-name *scans* that stopped at `-` (`emitStructLiteral`,
`koruStructToZig`'s `parseFieldAndValue`) learned the kebab-greedy infix rule.
Two further walls surfaced in the fix, both the same shape — a funnel that
only half-funneled:

- **A funnel with a prefilter must name every class it claims to rewrite.**
  `f.pos-tempo` in an arg value reaches `rewriteZigExpr`, whose `parsePostfix`
  now mangles `.field` segments — but the call never arrived:
  `zigExprMayRewrite` fast-rejected any text without `%`/`==`/`!=`, and a
  bare `f.pos-tempo` carries none. The rewrite existed; the gate hid it.
  `hasNonZigFieldName` now triggers the parse on `.`-segments with kebab or
  keyword names.
- **A funnel that runs half its passes leaks the other half's class.**
  Five sites called `escapeBoundNames` alone (bound names rewritten, `%` /
  string-eq / field segments untouched) where `lowerExprZig` — which runs
  both — was the funnel every other value went through. The four expression
  sites now call `lowerExprZig`; only whole-body `inline_code` text keeps the
  bare escape, correctly, since it is statements not an expression.

2026-09-22, second surface of the same belief, pinned 230_019: the rule is
not only *sites that write a name* but *text that contains one*. A `: i1`
bind declares `@"i1"` and `pos-tempo` declares `pos_tempo`, yet every
reference downstream lives inside author text spliced verbatim — template
`{{ expr }}` holes, when-guards, arg values, `_ = &x` discards. `i1`
resolves as the primitive type, `pos-tempo` parses as subtraction; both
yield "undeclared identifier" in generated code the author cannot open.
Decl and use must carry ONE spelling, and the use side is unfixable site by
site — a reference can hide inside arbitrary rendered text — so the correct
shape is a rewrite pass (`escapeBoundNames` over `replaceIdentifier`, the
established code-masked word-boundary rewrite) run at the text funnels:
`lowerExprZig`, the rendered inline body, raw arg-value writes, and every
`_ = &` discard. The funnel is the invariant's home; a name caught at all
thirty-odd call sites individually would drift again the same way the four
injection copies did.

2026-10-06, the boundary crossed in the other direction, measured on
once-campfire-koru: a site that *reads back* emitted spellings must
un-mangle. `dead_strip`'s `collectFromInlineBody` walks proc `.text` for
`_event.handler` references to keep synthesized callees alive — and extracts
`Frag_render`, the emitted Zig spelling, while the decl it must keep is
`Frag-render`, the source spelling. The two sets (`used` vs decl paths)
never intersected on any hyphenated name, so a koru/dom child component —
a call that exists ONLY inside opaque inline source, ONLY in emitted
spelling — had its render event dead-stripped out from under the parent's
generated code: `use of undeclared identifier 'Frag_render_event'` in code
the author never wrote. `markBareName` now marks the `_`→`-` variant too;
the emitter collapses `-`→`_`, so the spellings are one symbol. Same belief,
read side: **any site crossing the declared↔emitted boundary translates, in
either direction.**

2026-10-24, the C lane repeated the partial-funnel defect on its own
surface: `cMemberName` covered record fields, branch payloads, and
capture-cell stores — every site that had *needed* it so far — while
`struct <ev>_in` declarations, `__koru_in.<f>` bindings, and
`.f =` call literals wrote `f.name` verbatim. `320_036`'s
`{ outer-val: i32 }` emitted `int32_t outer-val;` — kebab→subtraction,
a syntax error ccomp caught downstream in code the author never wrote.
Same cross-product hole as the four injection copies: kebab names were
exercised on this lane in decl positions that never crossed an input
field, so the unmangled sites looked finished. The lane's rule now
matches the parent's: a declared name reaching emitted text goes
through the one spelling (`cMemberName` here), regardless of which
struct kind carries it.

Related:
[[frag-the-safe-koru-identifier-surface-is-smaller-than-the-language-says]] —
same wall seen from the author's side (keywords/primitives); this is the
emitter's side, and kebab is canonical, not exotic.
[[frag-a-name-mangling-dispatcher-assumes-a-parity-nobody-maintains]] — the
four-way copy is the same maintenance failure: N writers of "the same" rule,
zero owners of the parity.
