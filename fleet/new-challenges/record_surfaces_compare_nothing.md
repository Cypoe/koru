---
challenge: record-surfaces-compare-nothing
kind: frame
status: standing
yields: the remaining two positions of the record-field-set rule — `-> { }` bare returns and record-typed invocation args — refused at Koru level or an honest measurement that a ruling says they are legal
family: correctness
---

# Record literal field sets are still unchecked at two of three surfaces

Measured 2026-10-29 on worktree `024-the-tightening` (base `9f8576850`,
fix commit `fda830af7`). The `=>` branch-constructor surface now refuses
name-set mismatches (KORU030, pins 510_130/510_131). Two siblings of the
same enumeration still accept and reach stage-D Zig as
`no field named` / `missing struct field` / `extraneous field`:

1. **Bare-return records.** `pub tor make { seed: i64 } -> { a: i64,
   b: i64 }` with `make -> { a: seed }` or `make -> { x: seed, y: seed }`
   passes `--deep-check` (verified). The ctor's record is `plain_value`
   text; the declared shape is `EventDecl.return_type` text — both already
   parseable by `src/struct_literal.zig` (`checkRecordTextBindOnce` peels
   the same shapes for the bind-once rule). Check site candidates:
   `checkBareReturnOwnsPayload`/`checkImplMatchesDecl` (flow_checker) plus
   `validateImmediateImplShape` (shape_checker), which carries the TODO.
2. **Record-typed invocation args.** `sum { p: { a: i64, b: i64 } }`
   called `sum(p: { c: 3, d: 4 })` / `sum(p: { a: 3 })` /
   `sum(p: { a:3, b:4, c:5 })` all pass deep-check (verified). Arg value
   text vs the param's `Field.type` text — parse both with
   `struct_literal.parseFields`, compare name sets. The param record text
   is opaque, so the check belongs where that text is already parsed or
   must be widened to be — not a hand-rolled splitter (see the brief's
   quoting-surfaces rule). Label-jump args (`@loop(current: { v: 1 })`)
   verified in the same class — the KORU043 name check passes because
   `current` is a field; the VALUE shape is unchecked.

Ground: rung-3 self-grounding (all three verified emitting to Zig errors
against output_emitted.zig), plus the same stated law — "every constructor
supplies the field explicitly". The enumeration note is in
concepts/frag-the-tested-half-of-a-rule-is-the-half-that-is-real.md
(recurrence section, commit fda830af7).

Probes used (verbatim, all compiled then died in Zig at HEAD):
    make -> { a: seed }            # -> { a: i64, b: i64 }
    sum(p: { a: 3 })               # p: { a: i64, b: i64 }
    sum(p: { c: 3, d: 4 })         # note: collides with arm bindings —
                                   # `{ c: 3, d: 4 }` under `| done d`
                                   # mis-refuses KORU108 "not in scope" —
                                   # a wrong-tree false positive worth its
                                   # own look (the field 'd' read as a
                                   # binding reference)
