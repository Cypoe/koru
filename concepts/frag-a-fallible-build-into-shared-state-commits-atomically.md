---
type: belief
id: frag-a-fallible-build-into-shared-state-commits-atomically
provenance: 2026-10-12 — koru_std/compress.kz intermittent gzip corruption: a
  mid-build failure in the cached Huffman tree left new lengths against old
  codes and the next block emitted the seam. Found by gzip -dc round-trip,
  not by any pin.
ts: 2026-10-12
---

# A fallible build into shared state must commit atomically

A cached derived structure that is rebuilt **in place** — each step of the
build mutating the shared arrays — hands the next reader the seam between
two generations whenever a mid-build step fails. The failure is not where
the damage is: the failed block falls back and serves fine; the *next*
consumer inherits a cache that holds this generation's lengths against the
previous generation's codes, passes whatever consistency check it has (the
check reads the stale half), and emits bytes assembled from two different
trees.

The shape of the symptom: intermittent, input-distribution dependent, and
invisible to any oracle that only inspects the producer's own output — a
corrupt stream has a stable checksum, so a CRC pin over emitted bytes
certifies the corruption as "deterministic." The oracle has to be a real
consumer of the artifact's contract (an inflater), not a fingerprint.

The discipline is one line: compute into scratch, flip every shared cell in
one breath after the last fallible step. It applies anywhere a derived
structure is rebuilt while an older generation may still be served —
cached trees, baked indices, prepared plans — not only to Huffman tables.
