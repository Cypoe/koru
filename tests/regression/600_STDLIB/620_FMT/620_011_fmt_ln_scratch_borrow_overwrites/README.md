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
`string<scratch@scoped>`. The grammar: `@` joins a name (open vocabulary,
module-coined identity) and classes (closed vocabulary, compiler-enforced
rules), commutatively — `scratch@scoped` ≡ `scoped@scratch`. Identity
matching strips classes, so `scratch` acceptors and plain `l.text` reads
keep working; the class rule fires only at boundaries. Names are payload;
`!` and `@class` are grammar.

`scoped` means "may not occupy output position": `-> l`, `-> l.text`,
`-> { f: l }`, and `=>` payload fields all refuse KORU030 at the produce
edge — the callee's frame outlives the producer's, so the produce IS the
escape. This test is the MUST_ERROR pin for `-> l.text`.

The legal shapes, both pinned green:

- consume in place — `|> std/io:print.ln(l.text)` (620_001, 620_002)
- copy out — `std/string:from-page(l.text)` + `take` → owned
  `*String<instance!>` produced lawfully (620_012)

## Known residual

The class rides the binding, not its projections at parameter position:
`f(l.text)` sees `.text` as unqualified, so a callee receiving `.text`
through a param could re-produce it — class preservation across param
bindings is not yet implemented. The produce-edge check closes the
direct escape; the param path is the named next hole.
