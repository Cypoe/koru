---
type: belief
id: frag-a-field-sized-for-the-cap-is-a-ceiling
provenance: 2026-10-12 — std/compress multi-block: the match hash packed epoch-tag << 17 | (pos+1) into a u32 slot, sized back when inputs could never exceed 65535; the first >128KB input wrapped positions into the tag bits and `candidate - epoch_tag - 1` underflowed (integer-overflow panic on a 191KB body)
ts: 2026-10-20
---

A bitfield sized for today's input bound is not sized for the bound —
it is sized for the *assumption*, and the assumption is invisible. When
the cap moves, the field does not complain; it silently wraps and the
failure surfaces as arithmetic that looks correct until a large enough
input panics.

The compress hash slot packed `epoch_tag << 17 | (pos+1)` — honest when
`INPUT_CAP = 65535` guaranteed `pos+1 < 2^17`. Multi-block lifted the
cap and the same packing became a ceiling at 131,072 bytes, discovered
by a real input, not by review. The fix widened the slot to u64 with a
33-bit position — past gzip's own 4GB ISIZE wrap, so the field now
outlives the format's ceiling rather than the implementation's.

2026-10-20: the emitter's `[128]u8` indent buffer was the same shape in
a different organ. It was sized for "no continuation chain nests that
deep" — true for every hand-written chain in the corpus, false the
moment a synthesized seed emitted one continuation per markup element
(25 deep, index 132 > len 128, panic at emit). The input bound there
is not a format bound at all — continuation depth is *unbounded*
(generated ASTs do not know about 128), so no wider fixed size is
honest. The fix was not u64-for-u32: growable emitters allocate the
indent run from their allocator, and the fixed-buffer path (unit-test
emitters with genuinely bounded output) fails loud with
`error.IndentOverflow` instead of a silent wrap. 670_100 pins it.

The general rule for any packed field: the width should be justified
against the *format's* bound (DEFLATE window, gzip ISIZE, protocol
maximum), never against the *caller's current* bound. A caller bound
is policy; it moves without touching the field. A format bound is a
contract; it cannot move without a new format. And when there is no
format bound — when the input's depth is generated, not constrained —
the right field is a pointer into the heap, not a wider slot.
