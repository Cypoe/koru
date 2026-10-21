---
type: belief
id: frag-fmt-ln-scratch-is-sized-at-the-site
provenance: koru_std/fmt.kz ln transform — [size(16k)] step annotation
  on fmt:ln (2026-10-20)
ts: 2026-10-20
---

# The fmt:ln scratch is sized at the call site

`std/fmt:ln` formats into a threadlocal buffer *owned by that call site*
— the declaration is emitted inside each site's own inline block, so two
sites never share a buffer. RULED: the size is declared at the site, as
a step annotation — `|> [size(16k)]std/fmt:ln(…)` — digits with an
optional `k`/`m` suffix, absent: 4096.

The ruling, not just the syntax:

- The annotation sizes *this call*, not the library — there is no
  global knob, because the buffer is not global. A site that writes a
  giant label pays for its own scratch; the rest stay at 4KiB.
- Grammar position is the step annotation. Impl-head `name = [x]call`
  is the impl's slot and the parser refuses it there — `[x]name = call`
  would land on the impl's flow, describing every call inside it, which
  is the wrong semantics for a per-site size.
- A malformed size cannot refuse through SiteResult (no error channel) —
  it becomes `@compileError` in the emitted source: still compile-time,
  still a teaching diagnostic, never silent.
- Overflow is still a runtime panic, now naming the site's configured
  size; `fmt.blk` remains the uncapped escape.

Open: the same knob may belong on `print.ln`'s scratch and on oshun's
synthesized `ln.impl` bodies (which currently hardcode 4096) — both are
the same per-site shape and were left out of the first cut.
