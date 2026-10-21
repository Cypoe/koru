---
type: belief
id: frag-a-dead-frame-harvest-runs-zero-calls-deep
provenance: 440_030/440_036 — "the dispatcher owns its results" hid the fact
  that the owning call itself was the corruption vector
ts: 2026-10-21
---

# A dead-frame harvest runs zero calls deep (belief)

The dispatcher contract says results are borrowed memory and the interpreter
owns them — so the fix for stack-backed `|zig` returns was "copy the slice into
page memory at pack time." That fix was written as `__koru_own(s)` calling
`page_allocator.dupe`, and it read correct: the copy happens immediately, inside
the dispatcher, before the interpreter touches anything.

It was wrong in a way the source cannot show you: **the copy itself is a call,
and a call's frames land on the memory it was summoned to rescue.** `dupe` →
`alloc` → allocator internals descend into the stack region the callee just
vacated; whatever they write, they write over the payload *before* the memcpy
that was supposed to save it. Whether the bytes survive is frame-layout luck —
which is why the seam printed correctly for years and printed garbage the first
time a musl binary ran: same source, different frame arithmetic.

The invariant, then: **borrowed stack bytes can only be harvested by code that
makes no calls — the copy must splice into the frame that still borders the
dead one.** An `inline` byte loop into static storage does it; `dupe` cannot;
nothing dynamic can, because acquiring the destination is itself a call. That
is also why the fix carries a hard bound (64KiB per dispatch, panic on
overflow): an unbounded same-frame destination does not exist. The bound is
physics, not policy — a proc returning a stack slice larger than the snapshot
is a program error the gate names rather than silently truncates.

Two consequences worth keeping:

- **Multi-field payloads need the same window.** Field N's copy cannot follow
  field N−1's allocation — the allocation has already trampled the frame.
  Snapshot all borrowed bytes first, then spend calls.
- **"Owns it immediately" claims about call-mediated copies over dead memory
  are unfalsified until the frame arithmetic is checked** — a passing test
  proves the layout was lucky, not that the copy was early.
