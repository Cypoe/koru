---
type: belief
id: frag-the-callsite-cannot-spell-a-residual-case
provenance: Lars 2026-10-04 — "it makes sense on the declaration side but
  never on the call side"; `|?`/`!?` removed from grammar, emitter, and
  interpreter after ~11 months as a shipped feature
ts: 2026-10-04
tags: [toolchain, outcome-model, parser, interpreter, consumer-spelling]
---

# The call site cannot spell a residual case

A dispatch's arms name declared branches or are absent. There is no
catch-all spelling — not `|?`, not `!?`, not `|? Metatype b`, not any
form. `|?`/`!?` refuse at parse (PARSE003) on the compiled surface and as
`parse-error`/`MalformedContinuation` in interpreted source.

## Why the arm could never be made honest

A catch-all arm handles the set `O \ {named}` — a case the *consumer*
computed by subtraction, not a branch the producer declared. Writing it
authors outcome space at the call site, which is strictly worse than a
default: a default at least fills a slot the declaration defined; the
residual invents the slot.

Optionality is a property of the declared outcome, never of an arm. The
producer's `?` says "consumers are not obligated to handle this"; at the
call site there is nothing for "optional" to modify — an arm exists or it
doesn't, and not writing it IS how the grant is exercised. A `|?` arm is
literally a handler for the declared-needs-no-handler class: the two
halves of the spelling cannot both be true.

The evolution hazard was the sharper cut: producer adds `?debug`, and
every existing `|?` silently re-maps — consumer semantics change with
nobody authoring the change, in a direction the producer cannot audit
because it cannot enumerate callsites. Required-branch addition fails
loud (coverage violation); `?` addition into a wildcard failed silently
and behaviorally — the worst mode for an evolution mechanism.

## The interpreter boundary was the same violation, weaponized

`std/bridge:run` executes source text — in kopium, literally what the
model emits. A wildcard honored there hands the least-trusted writer in
the system an arm that absorbs any outcome it didn't name — including
`unhandled-branch` itself, the observation channel the refusal/honesty
loop runs on. The grammar and the flow parser now refuse identically;
440_020 pins `|?` answering `parse-error` from inside a bridge turn.

## The signature of the disease

Every rule written for named branches had to exempt `|?`: coverage skips,
unknown-branch skips, duplicate-ordering skips, a dedicated emitter
routing path, two AST fields threaded through eighteen files plus the
metacircular interpreter in koru_std. A construct needing an exemption in
every check is not a branch — it is a second grammar bolted onto the call
site. The privileges existed because the spelling existed.

## What stayed

- Declaration-side `?`/`?!` marks on branches — producer semantics,
  unchanged.
- The declaration-side raw-name class branch (`| \`*\` *` on regex:match)
  — the tor declaring an open outcome-name set; consumers still write
  only named arms (as codegen specification). Different axis entirely.
- `when` guards — they narrow one named branch, never widen coverage.
- Silent absorption: unnamed `?` outcome → nothing happens, because
  nothing was declared to happen. Absence is not a case.

## Open

- Whether the tor ever needs declaration-side behavior for unnamed
  outcomes (a declared fallback arm living on the declaration) — `?` +
  silent absorption may be the complete mechanism.
- Whether `KORU026`'s retired slot should ever be reused (convention so
  far: never).
- The audit this removal suggests: every continuation spelling judged
  against "names and binds" vs "generalizes" — `when` is the boundary
  case that survives by narrowing, but the same axis deserves the look.
