---
type: belief
id: frag-a-pin-file-read-raw-measures-the-checkout-not-the-compiler
provenance: 2026-10-18 — Windows CRLF sweep: three MUST_ERROR tests passed because `--auto-discharge=disable\r` was ignored; ~70 pin files carried \r; PARSER_TESTs with CRLF expected.json were red against LF actual
ts: 2026-10-18
---

# A pin file read raw measures the checkout, not the compiler (belief)

A regression pin is a program: `COMPILER_FLAGS` is argv, `ARGS` is argv,
`EXPECT` is the verdict contract, `expected.json` is the oracle. Every one of
those files is *bytes on a filesystem*, and the harness reads them with tools
(`cat`, `grep "^X$"`, `diff -q`) that treat the trailing carriage return as
content. On a Windows checkout (`core.autocrlf=true`), ~70 pin files carry
`\r\n` — so the program the harness ran was not the program the file pinned.

Measured reach, all from one byte:

- `COMPILER_FLAGS` → `--auto-discharge=disable\r` — an argv the compiler never
  claimed, silently ignored. Three MUST_ERROR tests (`330_025`, `330_113`,
  `330_115`) passed *for the wrong reason*: auto-discharge stayed on, the
  obligation was auto-discharged, and the pinned refusal never fired. A green
  that was measuring a mangled flag, not the leak wall.
- `EXPECT` → `FRONTEND_COMPILE_ERROR\r` — the anchored `grep -q "^…$"` refused
  to match, so a correctly-pinned frontend refusal was misclassified as a
  generic frontend failure. Red for the wrong reason — the pin was right and
  the reader disagreed with the checkout.
- `expected.json` → checked out CRLF, the compiler emits LF — `diff -q`
  reported every PARSER_TEST as `ast-mismatch` while the ASTs were
  byte-identical under normalization.
- `ARGS`, `JS/CS/C_REFUSES` — same class, same one byte.

## The belief

**Every read of a pin file is part of the measured program; normalize at the
read boundary or the pin grades the checkout's line-ending convention.** The
fix is never in the files (they are LF in the index; the CRLF is the
platform's doing) and never in the compiler — it is at each reader: `tr -d
'\r'` on flag/argv/marker input, `grep` against normalized content, `diff`
against normalized expected. The class is invisible until one file is
generated on the other platform — then an entire cluster flips and the flip
says nothing about the compiler.

Adjacent but distinct from `frag-a-verdict-read-from-an-artifact…`: that one
is an expectation that never inspected the exit code; this one is the
expectation's *input* being altered before it reached the subject.
