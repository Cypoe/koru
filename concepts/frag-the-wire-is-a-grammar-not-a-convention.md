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
