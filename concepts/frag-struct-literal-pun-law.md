---
type: belief
id: frag-struct-literal-pun-law
provenance: found this session chasing a to-do app's `insert { label: label }`; captured's bare form proven POSITIONAL (320_136); fix implemented by Grok 4.5, reviewed + landed 2026-07-23 (pins 320_136, 690_071, 690_072)
ts: 2026-07-23
---

# The struct_literal-block family obeys Koru's pun law — nothing positional, punning mandatory (belief)

Koru has two invariants: **nothing is positional** (fields addressed by name),
and **punning is mandatory** (`{ label }`, not the redundant `{ label: label }`;
a genuine rename `{ x: other }` is fine). Its destructure machinery enforces this
everywhere it runs (`! sweep { label }`, query projections, branch payloads).

But a whole family of constructs takes its `{ … }` block as a `source: Source`
(opaque text) parsed by a SEPARATE hand-rolled projector,
`struct_literal.parseFields` — NOT the destructure machinery. That family
(`captured`, `std/store:insert`, `std/store:stored`, store field-defaults, …) was
an ISLAND that never implemented the law, and each construct improvised a
different, wrong interpretation of a bare entry:

- **`captured { a, b }` was POSITIONAL** — a bare entry mapped to the cell's
  declared field BY INDEX (`cells[i].name`). Proven: the SAME two expressions,
  reordered, silently landed in DIFFERENT fields, no error (320_136). LATENT — the
  whole corpus only used the named form, so the positional footgun never fired,
  but it was live in the compiler. Positional, in the language that forbids it.
- **Store writes went the OTHER wrong way**: `insert { label }` (the pun) errored
  "missing column", while `insert { label: label }` (the redundancy) compiled
  silently — forcing exactly the shape destructures forbid, rejecting the pun they
  mandate.

## The law, now enforced in the shared parser (not per-construct)

The fix lives at the root — `struct_literal` itself — so the island dissolves and
every consumer inherits one rule (`punnableName`, kept in lockstep with
`lexer.punnableName`):

- **Bare punnable name/path** (`label`, `acc.sum`) → PUN by last segment
  (field = `label` / `sum`; value = the name/path).
- **Bare expression** (`a.x + 1`, anything with operators) → REJECT: *"positional
  assignment is never allowed — name the target (`x: expr`)"*. An expression can't
  pun (no name to match), so a positional fallback is the only alternative — and
  that alternative is the sin.
- **Redundant explicit label** (`x: x`, `sum: acc.sum` where the field name equals
  the value's last segment) → REJECT: *"punning is mandatory — drop the redundant
  label and write the bare pun"*.
- **Carve-out**: a SINGLETON bare non-punnable entry under
  `allow_singleton_expression` — capture's existing-value SEED
  (`capture { entity }` / `capture { expr }`). Write blocks
  (`captured`/`insert`/`stored`) leave it off, so a lone bare expression in a
  WRITE is rejected.

`captured`'s `cells[i].name` positional mapping was DELETED — there is no
positional path left anywhere.

## Why it matters / what it revealed

The bespoke island also meant store-write VALUES were raw text
(`insert { v: 2 + 2 }` passed `"2 + 2"` verbatim), so they likely bypassed Koru's
expression wall (KORU104, "no call in an expression"). Whether routing through the
real machinery closes that too is an OPEN follow-up (a `insert { v: <a call> }`
probe). The deeper principle: a construct that re-parses raw text instead of
consuming Koru's real destructure/expression nodes is an island, and islands
drift off-law — the fix is always to consume the real machinery, not to patch the
island's private parser.

Board Broken:0: the mandatory-punning rule forced rewrites of every
`field: path.field` site in the corpus (670_045, 810_091/092/131/132 — AoC, exact
outputs unchanged, so the rewrites are provably equivalent). 320_136 / 690_071 /
690_072 flipped RED→GREEN.

## A pun can also be destroyed UPSTREAM of the lowering (2026-08-08)

A third way to break the law, found in 210_025: the pun lowering itself was
correct, but a textual pass that runs BEFORE it — bare-return param
substitution (`substituteParamNamesInPlainValue`) — replaced the punned
identifier with the call-site value, so the lowering received `{ 10, 20 }` and
minted `.{ .10 = 10 }`: the VALUE promoted to field name. In a pun the
identifier is the name AND the value; any rewrite that touches one must
preserve the other. The substitution now expands the pun in place
(`{ x, y }` → `{ x: 10, y: 20 }`) when its match sits in punned field
position. Same law, new obligation: every pass that rewrites text upstream of
the pun lowering owes the punned name its survival.

## The call-arg tail was a second island (2026-09-24)

The law lived on `{ }` blocks and on ordinary tor calls
(`PARSE006: bare argument '37' does not name a parameter`) — but
`checkBareArgPunning` exempted **implicit-slot and machinery-only callees**
(`std/store:new`, `std/pump:create`, `std/list:*`, `std/indexes:*`, …)
wholesale. Free-form callees read `invocation.args` in their handler
bodies, so the exemption existed for name-matching — but it swallowed the
punning law with it, and each transform free-styled over the loose list:
`std/store:new(game, 37)` silently dropped the `37` (the capacity fell
back to default, unreported), `std/pump:create(main, 5)` dropped the `5`,
and an invented `std/channel(name: Proto, cap)` head *consumed* a
positional `16` as capacity. Three transforms, three different answers to
the same illegal input — convention instead of law.

The exemption is now narrowed to **name-matching only**: `args[0]` stays
the positional subject (the `expr: Expression` slot), every later bare
arg must be a punnable identifier path (`struct_literal.punnableName`) or
an explicit label — same PARSE006 diagnostic as a tor call. Found via
`had_explicit_label`, which `flow_parser.convertArgPairs` was silently
dropping on the interpreter path (along with `phantom_type`) — the
label-ness signal erased before the consumers that need it.

Pins: `210_240`/`210_241`/`210_242` (std heads refuse bare-literal tails,
including after a legal named arg), `210_243` (tor-call control).
The generalization that survives: **the pun law is a law about bare
arguments, not about any particular arg-list shape** — every new arg
surface inherits it only when the check sees the list, so islands are
found by probing each exempted callee class, never by assuming the shared
parser covers it.

## The labeled twin — a call binds each name once (2026-09-24)

The same silent drop had a second door, through *named* args. Measured:
`std/store:new(dogs, capacity: 64, capacity: 32)` compiled and emitted
`[32]i64` columns — the second `capacity` silently won. `~test(a test
block exists, expr: and a second)` — the PARSE006 hint applied literally —
compiled and emitted only the first `expr`. `checkBareArgPunning` verified
each arg *named* a param but never that a param got *one* binding, and on
free-form callees explicit labels skipped matching entirely.

The law completes: **a call binds each name once** — PARSE009 refuses the
second binding at the call. It holds on free-form callee labels too (the
labels are the callee's own data, but a repeat is still ambiguous) and it
catches the parser's own implicit `expr` remap colliding with an explicit
`expr:`. Synthesized marker args (`<implicit_source>`, `<program_ast>`)
are exempt — machinery gated on the slot's absence, not a user spelling.

So the surviving generalization tightens once more: the law is not "about
bare arguments," it is **about silent drops** — every arg must bind
honestly, and every name must bind once. Pins: `210_244`–`210_246`.

## The declaration side — a field list takes each name once (2026-09-24)

PARSE009 was written for call-site arg lists, and the same hole sat on
every *declaration-side* name list, all silently accepted by the frontend:

- `tor f { x: i64, x: i64 }` — input shape. Emitted `.{ .x = __koru_p_0,
  .x = __koru_p_1 }`; the backend died on Zig's `duplicate struct member
  name`.
- `| done { x: i64, x: i64 }` — branch payload shape. Same backend death.
- `=> done { x: a, y: a, x: 2 }` — branch constructor. `duplicate struct
  field name`; which value would have won is anybody's guess.
- `-> { x: i64, x: i64 }` — a record return type is a *string*, not a
  Shape, so no field list ever materialized for a checker to see.
- `@L(l.limit, limit: 2)` — a label JUMP's args. Worst of the set: no Zig
  error at all, the program compiled and *ran*, the second `limit`
  silently dropped.

The rule was never "a call binds each name once" — it is **a binding list
takes each name once**, and the frontend only saw one kind of list.
`enforceUniqueBindingNames` walks them all (PARSE010 on Field lists and
record-type strings, PARSE009 extended to label-jump args). Pins:
`210_247`–`210_251`; legal sibling `210_252`.

## Value position is a binding list too — but Source text is the
## transform's, not the frontend's (corrected 2026-09-24)

The first pass covered only lists the AST carried as `Field` nodes or type
strings. Two more surfaces held the same list as opaque value text:

- `f -> { x: a, y: 1, x: 2 }` — a record EXPRESSION lives in
  `ImmediateImpl.plain_value`, never a Field list. The frontend passed it
  through and Zig rejected the emission (`duplicate struct field name`).
  Puns bind too: `{ a, y: 1, a: 2 }` binds `a` twice.
- `captured { p: st.m, m: st.p, p: st.m + 1 }` — a Source-argument field
  list. Worse than the others: it compiled and RAN, the second `p`
  silently overwriting the first (printed `1 0`).

The first correction attempt got the enforcement site wrong — twice over.
It scanned EVERY invocation arg's text, including `Source` payloads, with
a shape heuristic, then exempted quoted keys by shape when
`std/build:variants`' string maps refused. That violated the atoms tenet
(frag-arguments-are-atoms): a `Source` arg is opaque text owned by the
transform that interprets it; the frontend may judge it only by the
parameter's DECLARED TYPE, never by the text's shape. It also built a
second field-list splitter beside `struct_literal` — two parsers for one
law, guaranteed to drift.

The correct shape: the one-name rule lives in `struct_literal` itself
(`DuplicateField`, re-derived name via `duplicateFieldName`/
`describeErrorIn`), so every consumer — `capture`/`captured` seeds and
writes, `const`, store inserts/stored, grids, the emitters — inherits it
through the parse they already do. `captured` refuses as KORU164 through
the transform's own ParseError path, caret on the Source's recorded
location (one line past the block in the measured pin — a pre-existing
Source-location convention, not introduced here). Record type strings and
record produce-values, which ARE Koru's own syntax held as strings, are
checked in the frontend by calling that same parser and translating only
its `DuplicateField` into PARSE010 — the declared-type judgment stays in
the frontend, the text judgment stays in the one parser.

What survives correction: the law — a binding list takes each name once.
What died: "the carrier is incidental." The carrier is exactly what
decides WHO judges: AST nodes and declared-type strings are the
frontend's; Source text belongs to its transform. Pins: `210_253`–
`210_255`; `210_252` extended with distinct-name record values incl. a
pun.

## The destructure list was a binding list the walker never visited (2026-09-24)

Two more carriers of the same list surfaced by following the emitter's
`emitDestructureConsts` — anywhere it writes `const <name>` per entry,
a repeated name is a Zig redeclaration:

- `| found { name, name }` — `Continuation.destructure`. Compiled clean,
  backend died on `redeclaration of local constant 'name'` (rung 3).
- `~f(): { name, name } |>` — `Invocation.return_destructure`, the
  bind-position twin. Same emission, same death. The walker had never
  entered `flow.body.node` at all — the head continuation's node was
  invisible to it.

`checkDestructureBindOnce` walks both carriers (and recurses `sub` — a
nested destructure is the same list one level down), refusing PARSE010
with the same message the field lists use. `_` is exempt — it is a
discard, not a binding, and repeats legally (`{ n, _ }`, 320_145).

The enumeration rule sharpened again: a binding list is found not by its
syntax but by *who emits a decl per entry*. The emitters know where the
lists are; the walker's job is to visit every site they write. Pins:
`210_269`, `210_270`.

The collision domain sharpened once more (2026-09-25): a leaf entry is
what emits `const <name>` — a field with a sub-shape emits nothing
itself — so a name can collide not only with its siblings but with every
leaf anywhere in the tree. `{ user: { x }, x }` emitted `const x` twice
and died `redeclaration of local constant` (rung 3, pinned `210_273`);
the sibling-level comparison the checker started with compared the wrong
set. The unit of the law is the emitted decl, never the syntax level.
