# fmt:ln scratch-borrow lifetime contract

Each `fmt:ln` call site emits its own `threadlocal` 4KiB scratch buffer
(`__S.__buf` in `koru_std/fmt.kz`), and `.text` borrows it. The lifetime
contract that follows is real and today it is unenforced:

- A `.text` is valid until ITS OWN call site runs again. Distinct sites
  never collide — a later `fmt:ln` elsewhere does not touch it — but a
  loop iteration, or the next request through the same flow path on the
  same worker, overwrites the previous render.
- Consequence: consume `.text` in place (print it, append it, compare
  it). Do NOT produce it into a record, a cell, a cache, or a return
  value meant to outlive this execution path — that is borrowing the
  scratch into a longer lifetime and it will corrupt silently.
- If the text must persist, copy it out: `std/string:from-page` +
  `take`/`detach` yields a plain `string`, or use `fmt.blk`, whose
  `string<allocated!>` obligation is the honest version of "this buffer
  is yours to settle."

## Known gap (unenforced)

`.text` types as an ordinary `string`, so the compiler cannot yet see the
escape — the rule above is convention, not law. The intended fix is a
phantom label with a scope-bound class (`string<scratch@scoped!>`), where
`@scoped` is a *class* in the checker's closed vocabulary meaning "may not
occupy output position" — refusing produce into a longer-lived field the
same way `string<unsanitized!>` refuses a taint sink (pin: 330_069), with
the synchronous consumers declared as acceptors.

`@` joins a name (open vocabulary, module-coined identity) and classes
(closed vocabulary, compiler-enforced rules); matching strips classes so
existing surfaces keep working, and class rules fire only at boundaries.
Names are payload; `!` and `@class` are grammar.

Until that lands, the contract above is the whole safety net — pinned as
observed behavior in `input.k` so the fixer is forced back here. When
`.text` gains the label, this test must STOP compiling and become a
MUST_ERROR pin.
