---
type: belief
id: frag-claim-stamps-are-standing-instruments
provenance: koru session 2026-09-27 — Lars, after the pump-capture work, on what `proven`/`measured` may mean; ruled in conversation, enforced by instrumented-stamps-resolve
ts: 2026-09-27
tags: [koru, claims, invariants, gates, honesty]
---

# Claim stamps are standing instruments, not certificates (belief)

A stamp above `aspirational` asserts discharged knowledge — `inferred`,
`measured`, `proven`. A bare assertion of discharge is the worst content a
codebase can hold: it reads as true and nothing checks it. A certificate
rots silently; an instrument either runs or fails loudly.

**Ruled (2026-09-27, Lars):** an instrumented stamp must NAME what keeps
discharging it, and the name must resolve. `- measured <x>` where `<x>` is a
pin under `tests/` or a path that exists; `- inferred <x>` where `<x>` is a
gate row that re-judges the claim every commit; `- proven <x>` where `<x>`
is a proof artifact plus its checker. `aspirational` names nothing because
it IS the residual — the honest undischarged claim, exempt by definition.

This is `std/todo`'s law pointed at the discharge side. An `owed` residual
is refused unless it names a witness test — visibility is not decidability
(frag-a-residual-becomes-drivable-by-having-a-body-not-by-being-declared).
A claim stamp is refused at the git gate unless it names a live instrument.
Same ontology: the residual is not the prose, it is the thing that runs.

**Continuous, not sampled.** Something true yesterday by measurement does
not need to be true today, so the check scans the working tree on every
commit — a pin deletion or a renamed gate row kills the instrument, and the
next commit fails regardless of which diff did the killing. An odds-sampled
row would let a dead instrument pass nine commits in ten; `instrumented-
stamps-resolve` is unsampled for exactly this reason.

**What this is not.** Not proof checking — Koru stays pragmatic; `proven`
names a checker artifact, never a prover built into the language. Not a
verdict on truth — the gate verifies the pointer resolves, not that the
claim holds; the instrument's own runs own truth. And not a reason to write
more stamps: `unclaimed` is the default and stays the default.

The prior shape this corrects: the stamp ladder documented `proven`/
`measured` as "discharged by runners" with no runners existing, so the top
of the ladder was self-assertion in a stronger adjective. In the wild the
corpus was already honest about it — five claims, all `aspirational`, zero
above it. The only stamps ever written were the ones requiring no
instrument.

## Open

- `proven` has no live checker yet — nothing is stamped it. The compiler's
  own structural guarantees (phantom lifecycle, required-arm totality) are
  the candidate first discharger, which would make `self` a resolvable
  instrument name. Undecided.
- `measured` resolves on pin *existence*; pin *greenness* (join against
  status.json) is the obvious next step and is deliberately deferred until
  the pointer form has worn in.
- Whether a dead instrument should degrade the stamp in `claims` output
  (effective grade drops to aspirational) rather than only failing the
  gate. The gate failure may be enough.
