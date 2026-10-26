---
type: belief
id: frag-a-colon-bind-must-see-past-an-inline-source-block
provenance: discovered implementing std/tree:mint — `mint(Node) {…}: n` dropped the bind; bind_colon stopped at the paren close
ts: 2026-10
tags: [koru, parser, bind, source-block, correction]
---

# A colon-bind must see past an inline source block

`call(args) { block }: name` is the same bind as `f(): name` and the same
as the multi-line `}: name` source-block close — but the parser's bind
scan (`bind_colon` in parseEventInvocation) stopped at the head's `)`
close and looked only at the next non-space char. An inline `{…}` sitting
between `)` and `: name` hid the colon: the bind was silently dropped —
`return_binding: null`, a synthesized temp at emit, and `return name`
undeclared. The multi-line path never had the hole; the single-line and
arm-joined forms did, which is why the miss surfaced only when a lane verb
(`std/tree:mint(Node) { … }: n`) spelled paren-args, an inline block, and
a bind on one line.

The law: after the head's `)` close, a top-level `{…}` is skipped before
the `:` check — a brace there is never arg data (args live inside parens),
it is the block. The destructure form `f() {block}: { a, b }` and the
pre-block bind `f(): n { … }` are unaffected; the fix only extends the
look-past.
