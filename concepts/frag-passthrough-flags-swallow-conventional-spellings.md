---
type: belief
id: frag-passthrough-flags-swallow-conventional-spellings
provenance: measured 2026-10-11 — `koruc main.k -O ReleaseFast` silently built Debug for an entire benchmarking session; every number that day read a bounds-checked binary
ts: 2026-10-11
---

# Conventional CLI spellings must be claimed explicitly — the pass-through bucket swallows them in silence (belief)

**Ruling.** Unknown `-`/`--` arguments land in a pass-through bucket and become
opaque backend flags by design — that channel is how `release=fast`, `build=os`,
and program-defined atoms ride without the frontend knowing them. The bucket is
correct *for invented spellings*. It is a lie *for conventional ones*: `-O` is
the optimize flag on every compiler the user's fingers know, and it fell into
the bucket as a dead flag while its argument became a stray positional (then a
`command=ReleaseFast` provider atom — silently harmless, silently wrong). The
build ran Debug. Nothing said so.

**The asymmetry is the tell.** A misspelled `--relase=fast` is a user's error
with an invented spelling — the bucket absorbing it is acceptable. `-O` is the
tool's own contract with the world — the user's expectation is *correct* and
the tool's silence is the defect. Spellings that mean something on every other
compiler (`-O`, and any future conventional claim) must be handled by name at
the frontend or rejected — never allowed to reach the bucket.

**What the fix looks like.** `-O` now consumes a mode argument (both `-O Mode`
and `-OMode`), maps the four Zig optimize modes onto `release=<mode>` flags,
and errors naming the supported set on anything else. `release=safe` and
`release=small` are plumbed end-to-end through all four consumption sites so
every mode a user can name actually produces that binary — a flag that parses
but doesn't work is the same class of lie one level down.

**The general move when adding flag-shaped surface:** if the spelling is
conventional, claim it; if a claim can't be honored yet, refuse it loudly.
The bucket may only ever see spellings nobody has a prior on.
