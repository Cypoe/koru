---
type: belief
id: frag-pipeline-steps-own-their-deeper-arms
provenance: campfire stopped compiling on post-residual-arms koru — KORU010
  stray continuations ×12 across cable/index.k; bisected to c7da83a40,
  reverted + pinned 210_318 on 2026-10-10
ts: 2026-10-10
---

# `|>` steps own their deeper-indented arms — arms attach to the current chain tail regardless of head kind (belief)

A `|>` step followed by deeper-indented `|`/`!` lines collects them as **its**
arms: `|> if (c)` + `| then`/`| else`, `|> for` + `! each`, `|> tor-call` +
`| ok`/`| err`. Attachment is the deepest-chain-tail fold — the step extends
the chain and becomes the tail its children bind to. Whether the head was a
pipeline step is not part of the rule.

`c7da83a40` (residual arms) added `if (head.pipeline_step) return head.cont;`
to `parseContinuationWithNested` and deleted the comment documenting why
steps collect: the flat-sibling fallback would otherwise hand the arm to an
earlier step and leave the keyword dispatch unhandled. The gate only covered
the `=`-body path — `!`-arm bodies kept nesting through
`parsePipelineContinuation` — so the tree briefly held two contradictory
rules and real code (campfire's cable) refused.

The reverted line is the pin's target: `210_318_eq_body_pipe_if_arms` runs a
`|> if(true)` with following-line arms inside a `worker =` flow body. Controls
`210_314` (attachment inside `!` arms), `230_004`, and the 355 residual
cluster stayed green — nothing in the residual corpus ever wanted the gate.
