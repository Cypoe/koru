---
type: belief
id: frag-a-verified-compilers-binary-is-not-thereby-reproducible
provenance: G-CC-4 scaffolding on the ccomp branch, 2026-10-11 — two runs of `ccomp -O gate_pin.c` differed in exactly 6 bytes
ts: 2026-10-11
---

# A correctness proof does not entail a reproducible binary (belief)

CompCert's theorem covers *what* the emitted code computes, not the bytes
the driver happens to write. Measured: `ccomp -O` on a fixed input twice
produced binaries differing at 6 bytes near 0x3459 — the driver feeds
`as`/`ld` a tempfile `compcert<random>.o` and GNU ld records that name as
an `STT_FILE` symbol. The object the proof is about is identical; the
artifact on disk is not.

Consequence for any gate that pins a compiler by hash: reproducibility is
a *recipe* (`ccomp -O -Wl,-s` — strip the symtab, the only observed
nondeterminism in a 3.18 link), never a default. And it must be *measured
per oracle*: the leak here was not a timestamp or a build-id — the two
usual suspects — but a tempfile name inside the proof-carrying pipeline
itself. A gate that assumes determinism from reputation would have been
green on paper and red on disk.
