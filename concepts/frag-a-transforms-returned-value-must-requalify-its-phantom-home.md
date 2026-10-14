---
type: belief
id: frag-a-transforms-returned-value-must-requalify-its-phantom-home
provenance: orisha's httparena handler moved its dataset into `std/store` custody at startup — the stored rows compiled inside orisha but every query result arrived at the caller with its phantom obligation erased or mis-homed, and the silent-drop probe (a `| done` arm past `std/store:query`) vanished without a diagnostic
ts: 2026-10-15
---

# A value a transform returns must re-qualify its phantom to the caller's module, not carry the declaration's (belief)

`std/store`'s transform-generated tors return typed things: a query yields rows,
`insert` yields a row handle. The phantoms on those returns are written in the
*declaring* module's namespace — `std/store` wrote `<borrow>` where it meant
`std/store:borrow`. Two separate leaks let the obligation evaporate:

- **Unqualified return phantoms.** A phantom state spelled bare inside a
  transform's generated declarations resolved against whatever module happened
  to be compiling the expansion — for a stdlib transform instantiated in app
  code, that is the *caller's* module, where the state name may not exist at
  all. The fix re-qualifies generated return phantoms (and bare pointer
  returns) with the declaring module's path at synthesis time.
- **Captured return bindings drop the obligation.** A binding captured through
  a transform call carried its type but not its phantom set, so an
  `*Row<borrow>` the caller received could be discharged or passed onward
  without the ledger ever seeing the debt.

The sibling mechanism — `home_ns` — was already how synthesized store cells
named their true declaring module; the returns path simply had not been put
through it. Now it is.

## The second half of the belief: a transform may not eat the caller's continuation

`std/store:query` is a transform site: it consumes the invocation node and
emits a sweep loop. A continuation arm the site never claimed — `| done`,
written because the caller thought of query as an ordinary chain — was
dropped *silently*: the node was replaced, the arm evaporated, the program
compiled and ran, and the continuation never fired.

That is a mis-compile, not a style complaint. `690_364` pins the refusal:
the compiler must reject an unclaimed arm on a transform site and name the
arm. Until that diagnostic exists the pin stands red — the bug is named and
catalogued, and shaping around it silently is the failure it exists to catch.

## What follows

- Any transform that synthesizes declarations with phantoms owes the same
  audit: does the phantom resolve in the *declaring* module, and do captured
  return bindings carry the obligation set? The two are one bug wearing two
  coats.
- Related: [[frag-a-bare-return-resolves-its-home-from-the-lifted-return-phantom]]
  — that belief governs the emitter's lowering of a declared return type; this
  one governs the transform's *synthesis* of it.
