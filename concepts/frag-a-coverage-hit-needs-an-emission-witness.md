---
type: belief
id: frag-a-coverage-hit-needs-an-emission-witness
provenance: adjudicating .kfuzz findings, 2026-10-02 — a GA finding scored
  `capture__read_lines` green under --deep-check, but the spliced AoC
  interpreter sat inside a `std/runtime:register` block whose line-scanner
  turned every line into an event name and dropped all of them unresolved
ts: 2026-10-02
---

# A coverage hit is text until the emitted artifact witnesses the construct (belief)

The composition fuzzer scores a hit when its detector sees construct A nested
under context B in the *source text*. `capture__read_lines__c87845` scored
exactly that: a `read-lines` fold spliced inside a register block, compiled
clean under `--deep-check`, filed as a live coverage hit.

The hit was counterfeit. `std/runtime:register` takes its block as `source:
Source` — opaque text ([[frag-arguments-are-atoms]]) — and its `parseEntries`
scans that text *line by line*: anything ending `(N)` is an event with a cost,
anything else becomes an event whose name is the whole line. `query = if(ask)`
registered as an event literally named `query = if`. Then
`findEventInfoHomed(...) orelse continue` dropped every entry that names no
tor — which is all twenty spliced lines. The program compiled green because
the payload was dead text in a block nobody semantically checks, not because
a read-lines-in-capture composition works. `koruc` never saw the construct
the detector credited.

## The shape

A `Source` argument is interpreted by the transform that owns it, and nothing
in the verdict distinguishes "the consumer kept this line" from "the consumer
dropped it." Any line-scanning DSL grammar — register is the measured one —
is a silent-drop surface: it accepts every line and keeps only what resolves.
Splicing into such a block produces a green that means *dropped*, not
*composed*.

## What follows

- **A green verdict needs an emission witness.** The check is not "did
  `koruc` accept the file" but "does the construct appear in
  `output_emitted.zig`" — the same discipline as
  [[frag-the-check-verdict-is-staged]] one axis over: that frag is the
  verdict lying about *stage depth* (`-c` cannot see emit refusals); this
  one is the verdict lying about *consumption* (the pipeline ran and never
  looked at the construct). A green at the deepest stage still cannot say
  whether the text was a program.
- **The silent drop is its own finding.** `register`'s unresolved-entry drop
  is unpinned: `prboe(1)` and a nonsense line inside `register { }` compile
  clean and vanish — measured 2026-10-02. Prior art treats the class as a
  defect (115_036's home-module fix exists because an unresolved *scope* was
  silent; 440_016 refuses a discharge claim on an unimplemented tor), but
  whether an unknown *entry* should refuse or warn is a design call.
- **Every `Source`-block DSL is suspect until read.** The drop semantics
  live in each transform's own parser (`capture { }`, store decls,
  `std/proto` bodies all take `{ name: type }`-shaped text through their
  own grammars). A census of which ones keep-or-refuse versus keep-or-drop
  is the actual coverage question.

## Open

- Whether `register` should refuse, warn, or stay silent on unresolvable
  entries — the `[REGISTRY] WARNING` precedent exists in the same function
  (440_016's discharge-phantom path).
- Which other `Source` consumers drop unresolved lines; each is a falsifier
  of any text-level coverage claim over it.
