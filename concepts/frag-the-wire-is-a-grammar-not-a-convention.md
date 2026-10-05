---
type: belief
id: frag-the-wire-is-a-grammar-not-a-convention
provenance: kopium R2 rung, 2026-08-17 — the wire parser landed as parse.wire in koru_std/runtime.kz with 430_059..430_062 green and the 440 bridge family intact
ts: 2026-08-17
tags: [koru, kopium, wire, grammar, derived, interpreter, agent-channel]
---

# The wire is a grammar, not a convention (belief)

Until R2, the language a model speaks to a Koru interpreter existed only as
prose: prompt text saying "one invocation, no chains, quoted strings," with
the general flow parser behind it accepting shapes the prompt forbade. A
convention the parser does not enforce is not a channel — it is a hope.
kopium's live turn 6 measured the hope: an English sentence parsed as an
invocation (430_055), and the refusal came back with the wrong meaning.

The ruling the R2 rung lands: **the wire is a restricted grammar, derived
from the register block, with no general-expression escape hatch.** One
invocation per turn; `verb(field: "value")`; nothing after the closing
paren. Prose, chains, truncated strings refuse at *parse* time, with
diagnostics written to be read by the model that emitted them.

**The unit of enforcement is the item, not the turn.** When turn
sequencing landed (a turn may carry several invocations under `?partial`),
the gate stayed on the single-item path — items 2..N skipped the grammar
entirely, and a bare value or a `when` clause mid-turn dispatched
silently. A grammar that only holds on the first line of a turn is the
convention this ruling retired. `std/bridge:run` now runs
`parse.wire` on every item before dispatch; a refused item is a
`step N/M parse-error` line and the turn runs on, pinned by 440_021.

The load-bearing split, the one that keeps the meanings honest:

- **parse-error** answers "that was not Koru" — the grammar's verdict.
- **event-denied** answers "a real verb that is not yours" — the scope's
  verdict, at dispatch.
- **validation-error** answers "that field is not on this verb" — the
  signature's verdict, at dispatch.

Collapsing any two of these teaches the agent the wrong lesson about its own
mistake, and the agent's next turn is built from the lesson we hand it.

The same honesty runs the other direction: **what the grammar admits, eval
must judge.** `| ok t when false |>` parsed full-fidelity into
`cont.condition` and `selectArm` never read it — the arm fired ungated,
and the wire was wider than the semantics it feeds (measured by kopium's
bridge-mirror, 2026-09-13). Admission is a promise: an admitted construct
that eval silently drops is a refusal that went off in nobody's direction.
`selectArm` now judges guards in source order — the arm's binding
provisionally in scope, first truthy guard wins, unguarded is the else —
pinned by 440_024. The remaining asymmetry is deliberately loud: a guard
that cannot be judged is `GuardUnjudgable`, a dispatch-error, never a
silent skip.

The third leg is that admission's edge must be *derived*, not paraphrased.
`parsewire.kz`'s header long declared "an unknown field on a known verb is
`validation-error` at dispatch" — a refusal nobody had built, silently
tolerated on every turn shape (bridge-mirror 2026-09-12-field-membership).
The wall that now exists does not carry its own copy of the vocabulary:
`validateFlow` walks the parsed flow and judges each invocation's named
fields against the scope's own `get_event_input` table — the same registry
data the prompt text and the dispatcher are emitted from. A verb that
gains a field gains the allowance in the same breath; the enforcement
cannot drift from the declaration because there is no second place the
declaration lives. Pinned by 440_025 — foreign field refused by name on
the head call, a mid-turn step, and a nested arm-body call; a name
outside the vocabulary is still `event-denied`, never a field complaint.

The fifth instance is inside the literal. **What the lexer tolerates for
boundaries, eval must honor as content.** The string scanner has always
tracked escapes (`\"` does not close the string) — the grammar admitted
`\n` on the wire, and `evaluateExpr` then materialized the literal as
backslash-n verbatim, because the AOT path never noticed: codegen
re-emits the raw text into a Zig literal where escapes resolve
downstream. The wire is the only path that *reads* the value, and the
value it read was the token, not the text. Measured live 2026-09-25: a
model's multi-line `edit()` wrote literal `\n` into a real file — the
agent cannot place a raw newline inside a quoted arg on a line-oriented
wire, so escapes were an admitted construct nobody could use.
`unescapeStringLiteral` now runs at materialization; unknown escapes pass
through untouched.

The fourth instance is the identifier itself. **A bare identifier in arg
position is a reference, never a literal** — and the two surfaces meet
that law at different walls. A top-level item head admits only quoted
values, so `echo(text: h)` dies at the wire parser ("no bare values") —
the grammar's verdict. An arm body is a Koru fragment, so `| ok t |>
echo(text: h)` parses, and the flow's validation judges it: `h` bound on
that arm path resolves, unbound it is `validation-error` naming the
name. Before this, an identifier that missed the environment fell
through to "return as-is" — `append(handle: h)` dispatched the literal
string `"h"` and failed `HandleNotHeld`, a refusal that blamed the
handle for the missing binding (bridge-mirror
2026-09-12-arm-composition). The walk scopes bindings per item along
the arm path: `| ok h |>` puts `h` inside that arm's subtree — a second
item and a sibling arm both see it unbound. Pinned by 440_026 — bound
reference resolves, cross-item and sibling-path references refuse by
name, `h.field` names `h`, and `-1` is still a number.

## Open questions

- Field-membership landed at pre-execution validation, not in the wire
  gate — `wireValidate` is scope-blind by construction, so the check lives
  where the scope's vocabulary is reachable. Still unjudged: argument
  *types* (the wire carries only strings; coercion failures surface from
  the dispatcher, not the gate).
- `430_055` pins the same prose-refusal against the *general* interpreter;
  whether `flow_parser` itself tightens is a compiler-core question, Lars's
  call.

The sibling surface landed the same day: `scope-grammar` renders the wire's
shape rules (kept beside the parser that enforces them) above the scope's
verb lines, and `std/bridge:grammar` extends it with the session's defined
flows — the prompt an agent lives under is now the register block plus its
own growth, pinned by 430_063 and 440_017. Prompt and enforcement are the
same bytes, completed.

2026-09-16 — the "completed" was measured false, then made true. kopium's
third vocabulary (`calc`, a handle-free domain) caught the last
hand-written bytes in the derived surface: the chain rule's worked example
was a fixed notes cast — `open | ok h |> append`, "the handle the call
just issued" — taught verbatim on a scope where both verbs are
`event-denied` and nothing mints a handle. The vocabulary list was
derived; the example above it was secretly the first domain's. The fix is
derivation, not deletion: `scope-grammar` now synthesizes the example from
the scope's own manifest — the head is the first verb that provably hands
a value to an arm (a payload-carrying branch, or a bare return minting on
`__type_ref`, which the wire meets as `ok`), the chain target is the
possession edge when one exists, else the lightest sink that can carry the
binding. On `notes` the derivation reproduces the old cast from data; on
`calc` it renders `add(a: "1", b: "2") | sum v |> say(text: v)`; a scope
with nothing provably chainable gets the rule with no fabricated example.
The limit that remains: a bare `-> string` with no phantom leaves no
manifest trace, so a scope of nothing-but-plain-returns renders the
no-example bullet — honest, and visible if it ever matters.

2026-09-30 — the gate still refuses, but refusal is now classified, not
flat. Live smoke against the airline scope showed models spell the
observer channel's argument as bare prose every time — `note(text: I see
my mistake...)`, `note: <prose>` — and the gate was wrong to count it:
the item was prose wearing the channel's costume, so it binds as observer
residue (captured, teachable, no strike) rather than a wire failure.
Re-read on 2026-10-02: those spellings were not failed quoting — the
models were inferring `text:` is a text-typed position. The wire's value
grammar is meant to be directed by the declared field type (`name<x>`
already proves a declared type changes what a position admits), so
`text: Source`/`Expression`-style decls — plain `name: Type` spellings
like `var: string` — are the mechanism the misspellings were voting for;
the flat head-arg validator is bootstrap scaffolding, not the design.

2026-10-04 — the ruling met Koru's own grammar. Call parens had hugged
their arguments in every file ever written — 0 loose `f( ` or `f(x )`
spellings across all 2,974 tracked `.k`/`.kz` — yet nothing refused the
loose form; it was a convention held by volume alone, until generated code
wrote `adx( g.qlen, ...`. C's whitespace tolerance is exactly the class of
admission this frag exists against, and the measurement showed the hope
shape precisely: the corpus was not disciplined, it was lucky. `parseArgs`
now refuses whitespace at either call-paren edge (`f(x)`, never `f( x` or
`f(x )`) — one check at the shared splitter, covering invocations, `|>`
steps, and `@label` jumps, skipped for paren-free callers so `{ a: 1 }`
record breathing stays legal. Pinned by `100_090_call_parens_hug_args`;
0-of-2,974 regression scan confirms the refusal is a wall around a
convention, not a break.

The same measurement surfaced the boundary
case the item-as-unit rule missed: `note(...)say(...)` on one line is
one item, and the malformed note was swallowing a well-formed call into
its residue string — the model's "my say() was treated as residue" was
literally true. The tail now splits at the first `)` whose suffix passes
the gate: note prefix to residue or dispatch, tail gets its own step.
`partial` counts `wire_failures` separately so a malformed-plus-working
pair still strikes — the bound's liveness guarantee survives the
generosity. Pinned by 440_037.

2026-10-02 — the vote is counted: the wire is now type-directed. The
scanner reads the scope's `input_fn` (and the bridge's host-verb table)
while it scans, so a value position's *declared* type decides its
spelling: `Expression` admits balanced expression text, `Source` admits
raw prose — including the colon form `verb: <rest>` for a verb whose lone
field is Source — and every admitted spelling normalizes to canonical
quoted wire before the interpreter's own parser sees it. One scanner,
two duties, same lookups: `wireGate` admits, `dispatchThroughScope`
canonicalizes, and what the gate admits is exactly what dispatch
executes. The `note(text: <prose>)` misspellings that residue-taught
through September now dispatch as real notes; `say(text: bare prose)`
still refuses, because `string` is not a captured-text type — the
distinction is the declaration, not the surface. The prompt half closed
with it: `introspection_verbs` renders at comptime from the same
`host_verbs` table the gate and `hostDispatch` enforce — prompt, parser,
and dispatch are one declaration read three ways. Pinned by 440_038
(marshal) and 440_039 (admission).

2026-10-05 — the drift ran the other way once too: a router believing
MORE grammar than the grammar. `segmentTurn`'s line scanner counted `'`
as a string delimiter and carried the state across lines, so an
apostrophe in narration ("I'll read…") opened a phantom string that
swallowed the wire item after it — the whole reply failed the gate as
`not_invocation` and bound as residue while correct wire sat inside it.
`runtime.wirescan.kz` had already ruled `'` a character ("an apostrophe
in captured text is a character, not a delimiter"); the ruling never
reached the sibling scanner. A router stricter than its grammar is a
silent kill — nothing refuses, nothing teaches, the model's valid wire
dies in transit. Same lesson as the admission edge: every scanner that
partitions the wire must read the wire's own alphabet, and the alphabet
has one quote. Pinned by 440_044; live witness: kopium `live.k` turn 5
(muse-spark emitted a correctly three-armed `read` that the segmenter,
not the model, destroyed).

2026-10-05 (bis) — the refusal must teach the RULE, not the symptom.
`say(text: prose with a comma)` broke as `expected ':' after the field
'I'` — mechanically true (bare Source prose stops at a top-level `,` or
`)`, the tail parsed as a field) and pedagogically useless: a model
retried the same shape until the six-strike bound killed the turn
(kopium task 40, smoke run). The grammar text now states the stop set
and the error itself names it. Admission edge honesty has a second
half: not only must the edge be derived, the refusal must be
self-teaching — a diagnostic that can't be learned from is a toll, not
a gate.
