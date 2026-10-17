---
type: belief
id: frag-a-class-confers-by-declared-contract
provenance: scoped-obligations worktree, 2026-10-17 — closing the
  fmt:ln param-laundering hole pinned in 620_013 forced the ruling:
  bodies are checked once per declaration while args are checked per
  call, so per-call class conferral is impossible and the contract —
  not the call site — must carry the class
ts: 2026-10-17
tags: [koru, phantom, classes, scoped, conferral, ruling]
---

# A class crosses a call wall only when the declaration spells it (belief)

`scratch@scoped` on `fmt:ln`'s product refused every direct escape —
`-> l`, `-> l.text`, record literals, `=>` payloads — and a one-line
identity tor laundered it anyway: `identity(data: l.text)` bound `data`
as plain `string` inside the callee and produced the borrow back
unqualified. Two mechanisms were missing: the arg wall resolved the
projection by suffix and never asked whether the *carrier* `l` was
classed; and classes did not confer through parameter binding at all.

The tempting fix — let the callee's binding inherit whatever class the
*argument* carried — is not available, and the reason is architectural:
event bodies are checked once per declaration, but call args are
checked per invocation. There is no per-call re-checking for conferral
to ride on. What a param knows about its argument's classes is what the
param's declaration says.

So conferral is **declared**: `string<*@scoped>` spells "any identity,
and this surface accepts frame-bound values" — it accepts the scoped
argument *and* binds the param scoped inside, so the callee's own
produce edges still refuse `-> data`. A plain `string` or `string<*>`
refuses the argument at the wall with a hint toward the declared
spelling. And the exit is symmetrical: `-> string<*@scoped>` is a
class-preserving reissue — a tor may forward a borrow to its caller
without laundering it, but only because the output contract carries
the class too. Acceptance buys in-place use; the declared output buys
forwarding; nothing buys removal.

The strict ruling — let unqualified params accept and re-bind
unqualified — was considered and rejected: it would re-create the exact
launder the wall exists to prevent, with the declaration pretending a
boundary the semantics then ignore. The contract, not the call site,
carries the class.

## Open questions

- View-returning tors (`split`, `trim`) still refuse scoped input
  conservatively: their output borrows *into* the argument, and
  output-borrows-input is a separate hole needing its own analysis —
  accepting scoped there without the output carrying the class would
  launder by a different door.
- Record-field class conferral is unenforced caller-side, so producing
  a record literal holding a scoped field stays refused even through a
  declared output — conservative until field-level conferral lands.
