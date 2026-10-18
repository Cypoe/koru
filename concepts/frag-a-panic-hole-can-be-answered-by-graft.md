---
type: belief
id: frag-a-panic-hole-can-be-answered-by-graft
provenance: std/panic landed 2026-10-14 in an adjacent session — the `catch` transform, `die` verb, and six pins under 681_PANIC; reviewed and marked green this session after the two MUST_RUN markers the harness demands were added
ts: 2026-10-15
---

# A `?!` hole can be answered once, by graft, instead of forty times by arm (belief)

`?!` is the optional-to-handle branch kind: unhandled at a call site it becomes
a synthesized `@panic` at that site — correct, but a program with forty callers
pays forty identical `| bad v |>` arms or forty crash holes. `std/panic:catch`
is the third option: a spelled, *pattern-scoped* graft. Its parens expression
reuses tap's selector grammar verbatim (`source` is a tor-path glob, `-> dest`
a panic-branch-name glob), and at every matched site where the `?!` is
unhandled the declared `!` arm is grafted in as the missing `|` arm —
`is_transformed_subtree`, proven by `std/control:capture`.

The verdict discipline is the belief's spine: a `?!` is the callee's terminal
product — nothing resumes it — so the grafted arm is the *tail* of the
abandoned path, and its ending is the honest answer to "was this resolved":

- `=> name payload` — not resolved, escalate: the panic re-offers as the
  enclosing tor's own declared `?!name` (681_006).
- `=> other` — resolved, rerouted into a different declared outcome.
- `die` — resolved by stopping; one verb per backend (`@panic`, `throw`).
- bare end — abandon; legal only where a path may end. Inside a producing
  flow a bare end would trade a loud crash for a dead path, so `catch`
  *refuses* the graft there unless every leaf ends in a verdict (681_004).
- every-grafted-arm-guarded gets a synthesized unguarded tail that re-panics:
  silence still means crash.

## What follows

- A catch can never quiet a crash it did not name — the pattern selects, the
  arms are deliberately non-exhaustive, and what escapes stays fatal.
- The mechanism is a transform graft, not a runtime handler: the answer is
  compiled into the site, so there is no handler frame to pay and no dynamic
  dispatch to audit.
