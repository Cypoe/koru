---
type: belief
id: frag-an-effect-arm-runs-inside-the-callees-custody
provenance: 2026-10-18 — 330_145 fix: `frames(win: w)` refused `window.size(win: w)` inside `! frame` because the checker read w as discharged inside the arm
ts: 2026-10-18
---

A `!` arm executes inside the callee's loop body, and custody of what
the firing call consumed moves with it.

When a call consumes a binding through a `<!state>` parameter, the discharged
mark the ledger leaves is correct for code AFTER the call and wrong inside
the call's own `!` arms. Inside the arm, the binding is live — its phantom is
the consumed parameter's states with the `!` markers stripped (`<!opened|!active>`
→ `opened|active`). That is why a mid-loop borrow like `window.size` can
honestly declare `*Window<opened|active>`: during `! frame`, the window really
is in those states — the loop holds it. The `!` (the debt) has moved to the
callee's custody; `| done`-style arms re-issue it when the loop returns.

Three edges bound the ruling:

- Only the firing invocation's OWN consumed arguments revive — identified by
  the syntactic arg site, not the tor's name. A binding an earlier call
  discharged stays dead inside the arm (pinned by 330_146).
- The revived state is live-without-debt: consuming parameters (`<!state>`)
  cannot be re-satisfied from inside the arm — the loop owns the obligation.
- On the post-call path nothing changes: the binding stays discharged after
  `| done` unless that arm re-issues it.

The earlier reading — "captures into `!` arms are poisoned unless a derived
binding accompanies them" — was never the rule. The apparent binding-shape
sensitivity was a transform graft hiding the authored tail from the ledger
(see the per-node-mark fragment); the verdict was non-compositional only
because validation was being skipped, not because capture analysis varied.
