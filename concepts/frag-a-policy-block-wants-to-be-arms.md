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
  against the decl — and pattern-name arms (`[within: 10 ticks]`, the
  `koru/odds` reflection channel) give declarations a metadata surface with no
  grammar cost.
- **The inline policy and a named policy share one vocabulary.** A future
  stateful policy (a signal model consuming the failure stream) produces
  `retry`/`exhausted` decisions — the SAME branches the inline arms spell.
  A rule list that outgrows counters graduates into a model whose tick
  produces the identical vocabulary; with a datablock the two paths would
  have needed two grammars.
- **Ordered rules arrive already ordered.** `restart: { err: 3, busy: 5 }`
  per-branch maps and `up_to`/`again` keywords were all going to be new
  grammar. As arms they are ordinary repetition plus `when`.

## Where the datablock still earns its place

A datablock remains right when the content is *data* — opaque text, a template,
a kernel body ([[frag-a-source-block-mints-declared-slots]]) — not when the
content is a decision list the language can already spell. The supervisor keeps
`{ restart: N }` as the terse spelling of `| retry t when t < N`, and mixing
block + arms on one site refuses loudly rather than merging.

## The parser facts that make it work today

- `|> mod:name` bare (no parens) parses as a zero-arg `.invocation` — the `:`
  disqualifies it from every branch-constructor path — so `matchesTransform`
  fires with no grammar change. A bare single-identifier `|> supervised` is
  claimed by produce-branch spelling; the vocabulary form needs `supervised()`.
- Children attach to the site continuation by strictly-deeper indent;
  same-indent arms land as siblings and fail loudly downstream.
- An arm's `|>` node arrives as `.invocation`, an arm's `=>` produce as
  `.branch_constructor` — the transform reads node kind, never text.

## Open edges, deliberately fenced

Re-entry `|>` is same-event only in v1 (the retry arms share one outcome
union). `| exhausted` produces in the child's vocabulary, not the parent's —
a parent-only terminal name refuses. Multi-field failure payloads refuse
(`__fail` threads exactly one field). The named-model path (`policy:`) is the
designed next rung, not yet spelled.

Reference: `koru_std/supervisor.kz` (arm-mode emission); pins 320_153
(re-spelled), 320_155 (ordered rules + exhausted produce), 320_156
(missing-bound refusal). Mechanism for the site-local rewrite itself:
[[frag-transform-continuation-position]].
