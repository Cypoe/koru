---
type: belief
id: frag-a-field-sized-for-the-cap-is-a-ceiling
provenance: 2026-10-12 — std/compress multi-block: the match hash packed epoch-tag << 17 | (pos+1) into a u32 slot, sized back when inputs could never exceed 65535; the first >128KB input wrapped positions into the tag bits and `candidate - epoch_tag - 1` underflowed (integer-overflow panic on a 191KB body)
ts: 2026-10-12
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

The general rule for any packed field: the width should be justified
against the *format's* bound (DEFLATE window, gzip ISIZE, protocol
maximum), never against the *caller's current* bound. A caller bound
is policy; it moves without touching the field. A format bound is a
contract; it cannot move without a new format.
