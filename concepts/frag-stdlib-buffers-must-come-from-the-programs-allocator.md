---
type: belief
id: frag-stdlib-buffers-must-come-from-the-programs-allocator
provenance: orisha's pure-Koru httparena handler — a gzip'd response body allocated by std/compress via page_allocator reached the pump's post-send free through koru_allocator() and the process aborted; fixed 2026-10-14, the first closed cost in orisha's challenge catalog (gzip-allocator-pairing)
ts: 2026-10-15
---

# A stdlib buffer handed to the program must come from the program's allocator (belief)

`std/compress`'s allocating `gzip` tor picked `page_allocator` for its output
slice. That choice is invisible until the buffer crosses a boundary: Orisha's
response contract frees `body_allocated` bodies after send through
`koru_allocator()` — and a `page_allocator` buffer reaching that free is a
libc `free()` on the wrong allocation, i.e. an abort under load, not a leak
you could audit.

The rule: a stdlib surface that yields a buffer the *program* will own must
allocate it through `koru_allocator()`. The allocator is part of the buffer's
contract, and the contract is set by the consumer's free path, not by what is
convenient inside the producer.

`detach` on `std/string:String` is the same belief from the ownership side:
it consumes the String and yields the owned slice outright — the move-sibling
of `snapshot`, which copies and keeps the String alive. A custody hand-off
(body → Response → post-send free) wants the move; a read wants the copy.

## What follows

- Any stdlib tor returning an owned buffer owes the same question: which
  allocator minted it, and does that match every declared free path? Grep
  `page_allocator` inside `koru_std/` producers; each hit is a candidate
  mismatch.
- The crash was not a compress bug or an Orisha bug — it was a *pairing*
  failure between two locally-correct choices, which is why neither side's
  tests caught it alone.
