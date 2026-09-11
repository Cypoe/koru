---
type: belief
id: frag-a-synthesized-pun-arg-is-name-bound
provenance: surfaced building koru-libs/examples/style_reuse.k (the scalar-bind
  pun never fired on `koru/vaxis:write-styled`); fixed 2026-09-11 — pin 210_218
ts: 2026-09-11
---

# An arg the desugar synthesizes binds by NAME, never by append position (belief)

`desugarBindingPuns` appends its fill at the END of the arg list: the arg's
position in the list says nothing about which parameter it binds. Every consumer
that resolved `name == value` args by index (`fields[i]`) was re-binding the fill
to whatever field happened to sit there — a misbinding that stayed invisible for
months because every pinned case happened to append at an aligned index
(210_154's `text` fill lands at index 1 of `[x, text]` — index 1 *is* `text`).
The first unaligned consumer was `style_reuse.k`: `write-styled`'s `style` fill
appended at index 3 over fields `[x, y, text, style]` — index 3 is `style`,
still aligned — while a probe's `write-at(x)` fill appended at index 2 over
`[x, y, text]` rebound `x` onto `text` and died KORU080 on the param it had just
filled.

The rule now lives in `ast.resolveArgFieldIndex` / `resolveArgParamName`: a bare
pun (`name==value`, no written label) names its field and binds it wherever the
name matches; index is the fallback only for a name that is no field —
transform-emitted positionals like the dock child's prepended `win`. Eight sites
converted (KORU080 arity, auto-discharge, phantom checker, emitter arg emission,
default-supplied detection, template context keys). Site callers that only need
"positional or not" now get the honest answer: a pun naming a field is
name-bound, not positional.

## Same fix, second half: fill selection compares unqualified bases

The binding's recorded type keeps the producer's module qualifier
(`koru/vaxis:Style`) while the param's stored field type normalizes it off
(`Style`). `typeCanFill` compared verbatim and missed — the pun fired only for
intra-module types. `typeBasesEql` now compares bases qualifier-free — the same
convention `phantomStateName` already applies to phantoms and the store applies
to `*Type` columns. A leading `*` stays significant (`*Pending` ≠ `Pending`).

## Adjacent ruling

`_` is a discard, not a binding. `| ok _` seeded `_` into pun scope at the
payload's type, and a consumer's open slot of that type filled from the discard
(`use()` emitted `.n = _`). Phase A/B scope seeding now skips `_` — the slot
stays unfilled and KORU080 reports it, which is the honest outcome for a param
nobody supplied.

## Scope / not-yet

- `main.zig`'s comptime-thunk emission still maps positional-looking args to a
  hardcoded `text` field (no signature in scope there); pun args inside comptime
  thunks ride that heuristic unchanged.
