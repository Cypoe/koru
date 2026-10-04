---
type: belief
id: frag-a-coverage-hit-needs-an-emission-witness
provenance: adjudicating .kfuzz findings, 2026-10-02 — a GA finding scored
  `capture__read_lines` green under --deep-check, but the spliced AoC
  interpreter sat inside a `std/runtime:register` block whose line-scanner
  turned every line into an event name and dropped all of them unresolved;
  extended 2026-10-04 when the counterfeiter turned out to be the
  compiler's own checker — branch_checker granted `|?` required-branch
  coverage the emitter never wired
ts: 2026-10-04
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
- **Drop has a twin: fuse-and-emit.** The same evening, GP scored
  `store__capture` green on a splice that put a `! row e |> store:take`
  watch inside a `captured { }` field. `struct_literal.parseFields` split
  the block on top-level commas only, so the tor line fused into the
  field's value — and the emitter pasted it *verbatim into the Zig*:
  `acc.n = acc.n + 1\n! row e |> std/store:take(arena[e]);` — text that
  fails `zig ast-check`. Nothing dropped it; it shipped. `--deep-check`
  writes emission without checking the emission parses. Fix: a depth-0
  newline followed by a statement head (`!`, `|`, `~`, `=>`, `#`) inside a
  field value is refused as `FusedStatement` (KORU164, names the line) —
  pinned by 100_089, which sits beside 100_083's unclosed-paren twin.
  The witness rule sharpens again: the witness must appear in emitted
  output that is itself parseable.
- **Drop has a third sibling: transform-bypassed check.** `gp_1_pass`
  scored green on a `| missing` arm under a bool-`if` inside a `| captured`
  continuation — a shape the `| done` sibling refuses KORU021
  ("has no branch 'missing'"). The capture transform consumes the subtree;
  the unknown-branch check never re-runs on it, and the emitter renders
  the arm as an *empty* `else` — steps carrying unbound names vanish.
  This one defeats even a parseable-emission witness: the emitted Zig is
  valid, the arm's body simply isn't there. The witness must show the
  construct *semantically present* (its steps' effects), not just a
  syntactically plausible skeleton. Pinned red: 510_125.
- **Dead code is a hiding place.** `gp_2`/`gp_11` spliced Koru-looking
  lines inside `proc|zig` bodies of tors `main` never calls — dead_strip
  removed the whole proc, the construct never reached emission, PASS is
  vacuous. A coverage hit requires a *live* carrier: reachable from an
  executed root, not merely compiled.
- **The checker can be the counterfeiter.** `branch_checker` let `|?`
  satisfy required-branch coverage — its doc comment and two unit tests
  called it law — while the emitter routes optional branches only. A
  required arm left to the catch-all passed the whole frontend and died in
  Zig codegen on switch exhaustiveness: the witness was absent and the
  failure arrived two layers down wearing the wrong diagnostic, on both
  `|` outcomes and `!` effect links. The grant was deleted, not widened —
  every executable pin (355 cluster, the emitter's `is_optional` gate,
  the interpreter's honest `unhandled-branch` outcome) already agreed
  that `|?` never substitutes for a named required arm; only the checker's
  prose dissented. A coverage rule with no emission path behind it is not
  a relaxation, it is a refusal deferred. Pinned: 355_013.
- **The suppressor can be the counterfeiter too.** `auto_discharge_inserter`
  treated `|?` as answering everything left — so an unhandled `| ?!` panic
  variant and a `~[prototype]` hole both lost their synthesized `@panic`
  arms, and codegen died on the missing variant instead. The grant was
  silent twice over: no arm emitted AND no arm synthesized. Now `|?`
  silences only the optional no-ops it actually routes; panic arms and
  prototype holes still synthesize. Pinned: 355_014, 400_206.
- **A catch-all with no union to catch is the same grant in negative.**
  `|?` on a pure-effect, bare-return, or void callee attached a fallback
  to a dispatch that has no outcome switch: emission dropped the
  invocation outright (unused block label) or ran the arm's body on every
  call. Neither checker had asked the question "is there anything here to
  catch". Refused as KORU026 in both flow_checker and shape_checker;
  pinned 355_015, 355_016. The full shape census — guarded `|?` (KORU103),
  guard-only required with `|?` (KORU050), class branch `| \`*\` *` with
  an unnamed required branch (KORU022), the interpreter's honest
  `unhandled-branch` (440_020) — already agreed; only these three seams
  dissented.

## Epilogue (2026-10-04)

The construct whose grant this frag adjudicated was later removed entire:
`|?`/`!?` refuse at parse (PARSE003) on both compiled and interpreted
surfaces — see [[frag-the-callsite-cannot-spell-a-residual-case]]. The pins
cited above were re-pointed to that refusal (355_013/015/016, 440_020) or
rewritten without the arm (355_014, 400_206); KORU026 is retired
unreachable. The witness lesson stands — the counterfeit was real, the
audit found it — but the machinery it audited no longer exists.

## Open

- Whether `register` should refuse, warn, or stay silent on unresolvable
  entries — the `[REGISTRY] WARNING` precedent exists in the same function
  (440_016's discharge-phantom path).
- Which other `Source` consumers drop unresolved lines; each is a falsifier
  of any text-level coverage claim over it.
- Whether `--deep-check` should `zig ast-check` its own emission — the
  oracle currently cannot distinguish "emitted" from "emitted valid Zig".
