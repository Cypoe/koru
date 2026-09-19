---
type: belief
id: frag-a-policy-block-wants-to-be-arms
provenance: std/supervisor arm-policy session 2026-09-19 — the `{ restart: N, args: {…} }` datablock was re-spelled as `| retry` / `| exhausted` continuation children; koru/odds' `[tag: description]` reflection was the precedent
ts: 2026-09-19
tags: [koru, transforms, dsl, source-block, supervisor, policy]
---

# A transform's decision vocabulary wants to be continuation arms, not a `source:`-text DSL (belief)

When a `[comptime|transform]`'s input is a *decision* — an ordered rule list, a
policy, a set of cases — the first instinct is a datablock: `transform { key:
value, … }` lands as a `source:` arg whose text the handler re-parses
(`struct_literal.parseFields` or worse). That is a **second grammar inside the
first one**, and it re-derives by hand what the outer grammar already gives for
free. The better surface is the site's own continuation children:

    | refused f |> std/supervisor:supervised
        | retry t when t < 5 |> dial(port: f + 1)
        | exhausted => refused f

Every piece of the policy is native machinery: the branch *name* is the
vocabulary (`retry`, `exhausted` — checked, refusing unknown arms with a
diagnostic), the *binding* names state the machinery supplies (the retries-spent
counter rides like a payload), `when` is the same `when` every arm carries, a
`|>` continuation is a real re-entry call with real labeled args, and `=>` is a
real produce. Nothing is parsed twice; the transform walks
`site.continuations` as typed AST.

## Why it is stronger than the datablock, not just prettier

- **The decision vocabulary becomes checkable.** `args:` naming a field the
  child does not take was a string-level validation the transform wrote by
  hand; `|> dial(port: f + 1)` is an ordinary call the transform validates
  against the decl.

- **The inline policy and a named policy share one vocabulary.** `policy:
  Name` landed on exactly this: a same-module tor consuming `{ f: <payload>,
  t: i64 }` produces `retry`/`exhausted` — the SAME branches the inline
  arms spell. `t` is required (the bound channel — the compiler cannot see
  the escape inside an opaque tor; `within` is a throttle, not a bound).
  `f` is optional (a counter-only policy is legitimate). `retry`'s payload
  IS the re-entry arg map — positional `| retry i64` for a single-input
  child (Koru refuses named single outcomes, so partial adaptation is
  unspellable — consistent), named fields for 2+. `exhausted` bare forwards
  in kind; `| exhausted <v>` produces on the supervised branch. The signal
  composition still graduates this: a stateful model consuming the failure
  stream produces the identical vocabulary — the delegation channel is
  already shaped for it.
- **Ordered rules arrive already ordered.** `restart: { err: 3, busy: 5 }`
  per-branch maps and `up_to`/`again` keywords were all going to be new
  grammar. As arms they are ordinary repetition plus `when`.

## The two slots are kinded — the block is the declaration slot, arms are the rule slot

The `within` declaration first landed as a `| [within: 10 ms]` arm and the
spelling was wrong in a way that taught: a bare arm — no `|>`, no `=>` — is
legal Koru and means "on this outcome, swallow it." A declaration arm reads
to the grammar as outcome dispatch with an impossible outcome, surviving
only because a transform owns its children's vocabulary and the branch
checker never sees them. The anomaly pointed at the real structure: **the
site has two slots, and each content kind has its own.** `{ }` on the
invocation is the data slot; continuation children are the decision slot.
Declarations are data — they belong in the block:

    | refused f |> std/supervisor:supervised { within: 10 ms }
        | retry t when t < 5 |> dial(port: f + 1)

So the block's fields split by kind: `restart:`/`args:` are *rule-source*
(they spell decisions — mixing them with rule arms is the two-spellings
refusal), while `within:`/`policy:` are *modifiers* that parameterize
whatever rules exist and compose with either spelling — `{ restart: 3,
within: 1 s }` is shorthand-plus-spacing with no arms needed. A modifier
with no rules refuses ("nothing to space"). The arm-form `| [within: …]`
died with a teaching refusal — one spelling per content kind, or the two
slots drift back into ambiguity.

`[…]` is Koru's existing metadata marker — `f[ann]` binding annotations,
`[tag: desc]` pattern names, `[pure|async]` proc annotations — and the
lesson is positional: metadata attaches to the noun it modifies. `within`
modifies the supervised *site*, and the site's own data slot is the block.

The ruling that mattered more than the mechanism: **`within: 10 ticks`
refuses.** On a call the only in-scope clock is the attempt index, and on a
pure failure stream "M restarts within N attempts" degenerates — every event
IS a restart, so the window check collapses to the `when` bound the arm
already carries. A tick clock has a supplier — an enclosing signal model —
and its absence is the refusal's whole message. So vocabulary may be *pinned*
before its supplier exists: `within: 10 ticks` parses, validates, and
refuses with the name of the missing supplier, which lands the composition
boundary in a diagnostic rather than a doc. `policy: Name` turned out not
to need that wait — its supplier is ordinary same-module event lookup, so
it landed as delegation to a stateless tor; the signal-model supplier only
adds *state* to what the channel already delegates.

## Where the datablock still earns its place

A datablock remains right when the content is *data* — opaque text, a
template, a kernel body ([[frag-a-source-block-mints-declared-slots]]) —
and policy *declarations* are exactly that kind of data. What the arms
abolished was not the block but decisions-in-a-string; what the `within`
re-spell abolished was data-in-an-arm. Neither slot is the DSL; smuggling
the wrong kind into it is.

## The parser facts that make it work today

- `|> mod:name` bare (no parens) parses as a zero-arg `.invocation` — the `:`
  disqualifies it from every branch-constructor path — so `matchesTransform`
  fires with no grammar change. A bare single-identifier `|> supervised` is
  claimed by produce-branch spelling; the vocabulary form needs `supervised()`.
- Children attach to the site continuation by strictly-deeper indent;
  same-indent arms land as siblings and fail loudly downstream.
- `|> X { data }` and deeper-indented arm children COEXIST on one site —
  the block text arrives as the `source:` arg and the arms as
  `site.continuations`. That coexistence is what makes the kinded split
  grammatical rather than conventional: the data slot and the decision
  slot are both real, so each kind gets its own.
- An arm's `|>` node arrives as `.invocation`, an arm's `=>` produce as
  `.branch_constructor` — the transform reads node kind, never text.

## Open edges, deliberately fenced

Re-entry `|>` is same-event only in v1 (the retry arms share one outcome
union). `| exhausted` produces in the child's vocabulary, not the parent's —
a parent-only terminal name refuses. Multi-field failure payloads refuse
(`__fail` threads exactly one field). `within` honors wall-clock units only
(`ms|us|ns|s`) — `ticks` is pinned, not supplied. `policy:` delegates to
same-module tors only — cross-module paths refuse, and a stateful policy
awaits the signal composition it was shaped for. Rule-source fields
(`restart`/`args`/`policy`) do not combine with rule arms or each other;
the `within` modifier composes with every spelling. Arm-shaped
declarations (`| [key: value]`) refuse with teaching — the block is their
home.

Reference: `koru_std/supervisor.kz` (arm-mode emission) + `.decl.kz`
(within) + `.policy.kz` (delegation) + `.h.kz` (shared helpers); pins
320_153 (re-spelled), 320_155 (ordered rules + exhausted produce), 320_156
(missing-bound refusal), 320_157 (`within` honored), 320_158 (`ticks`
refusal), 320_160 (declaration-arm refusal), 320_161 (`restart`+`within`
compose), 320_162 (policy delegation), 320_163 (missing policy refusal),
320_164 (`t` required), 320_165 (policy+`within` veto). Mechanism for the
site-local rewrite itself: [[frag-transform-continuation-position]].
