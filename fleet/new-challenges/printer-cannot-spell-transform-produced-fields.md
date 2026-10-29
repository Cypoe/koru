---
challenge: printer-cannot-spell-transform-produced-fields
kind: frame
status: standing
yields: an ast_printer gap closed — minted impl flows (and inline_code items) get a surface spelling, or a ruled-IR list documenting which shapes are unprintable by design
family: toolchain
created: 2026-10-29
---

*Measured 2026-10-29 on Cypoe/challenge-025-what-the-compiler-writes
(df5c324a4): running `koruc explain` on a store program prints the
transform's own output — and one minted item refuses:
`flow __store_sweepbody_<s>_L<line>_<tag>: the printer cannot spell it
(UnprintableNode)`, gated at src/ast_printer.zig on `flow inline_body
(transform-produced)`. The store transform mints the impl flow with
`inline_body = null`; a later pass in `process_all_transforms` fills the
field, so the tree IS shaped like a flow the user could write — but the
printer refuses on the field's presence, not the tree.*

## The brief (sealed — you are the contestant)

**Decide for each printer refusal whether it is a printer gap or a
language gap, and close the ones that are gaps.**

`ast_printer` refuses whole categories (`inline_code (IR)`, `native_loop
(IR)`, `fused_event (IR)`, `event_tap (transform-produced)`,
`label_decl`, `flow inline_body`, `flow preamble_code`, `module_decl
(post-merge tree)`). Two questions per refusal:

1. Does the item's tree have a faithful surface spelling? The sweepbody
   impl flow's continuations are ordinary Koru — `inline_body` is a
   cached copy of source the tree already carries, so printing the tree
   and ignoring the field is the honest answer. `inline_code` is
   different: raw host text with no Koru surface — that one is IR by
   design and the refusal is correct.
2. If the printer should spell it, make it: teach `printItemSource` (or
   the caller's copy) to print the tree form, and flip the relevant row
   in `690_378` from "the printer cannot spell it" to printed source.

If a refusal is a language gap instead (the compiler produces a shape
users cannot write and there is no faithful spelling), say so and pin it
— that is a finding for the surface-design wall, not a printer fix.

Out of scope: making `inline_code`/`native_loop`/`fused_event`
spellable. Those are IR by construction; the finding is only about
nodes whose tree form is real Koru (flows, continuations, decls) gated
by a transform-produced FIELD.
