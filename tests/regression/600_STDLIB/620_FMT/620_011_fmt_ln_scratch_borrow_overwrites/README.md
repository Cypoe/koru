# fmt:ln scratch-borrow lifetime contract

Each `fmt:ln` call site emits its own `threadlocal` 4KiB scratch buffer
(`__S.__buf` in `koru_std/fmt.kz`), and `.text` borrows it. The lifetime
contract is enforced by the compiler:

- A `.text` is valid until ITS OWN call site runs again. Distinct sites
  never collide — a later `fmt:ln` elsewhere does not touch it — but a
  loop iteration, or the next request through the same flow path on the
  same worker, overwrites the previous render.
- Consequence: consume `.text` in place (print it, append it, compare
  it). Do NOT produce it into a record, a cell, a cache, or a return
  value meant to outlive this execution path — that is borrowing the
  scratch into a longer lifetime and it will corrupt silently.
- If the text must persist, copy it out: `std/string:from-page` +
  `take`/`detach` yields an owned `*String`, or use `fmt.blk`, whose
  `string<allocated!>` obligation is the honest version of "this buffer
  is yours to settle."

## Enforcement (landed)

`fmt:ln`'s bound product (`l` in `fmt:ln(...): l`) carries
`string<scratch@scoped>`. The grammar is positional: the name holds the
first position, classes join after it (`name!@class@class`); the name
atom is where `!` binds — `alloc!@scoped` issues a confined obligation.
Class vocabulary is open — the compiler enforces `scoped` and carries
any other class inertly for modules to honor. Identity matching strips
classes, so `scratch` acceptors and plain `l.text` reads keep working;
the class rule fires only at boundaries. Names are payload; `!` and
`@class` are grammar.

`scoped` means "may not occupy output position": `-> l`, `-> l.text`,
`-> { f: l }`, and `=>` payload fields all refuse KORU030 at the produce
edge — the callee's frame outlives the producer's, so the produce IS the
escape. This test is the MUST_ERROR pin for `-> l.text`.

The legal shapes, both pinned green:

- consume in place — `|> std/io:print.ln(l.text)` (620_001, 620_002)
- copy out — `std/string:from-page(l.text)` + `take` → owned
  `*String<instance!>` produced lawfully (620_012)

## Known residual

Scoped values cross parameter walls only by declared contract:
`f(l.text)` into a plain `string`/`string<*>` param refuses at the
argument wall (620_013); a param declared `string<*@scoped>` accepts and
binds the value as scoped inside the callee (620_014), and only an
output declared `-> string<*@scoped>` may reissue it (620_015). What
remains open: record-literal produce with a scoped field refuses even
when the declared output field carries the class — field-level conferral
is not yet implemented, so the conservative refusal stands.
