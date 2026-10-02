---
challenge: teaching-surface
kind: frame
status: standing
yields: one surface that now teaches its own usage at the point of misuse — a line or fewer, in the output the agent was already looking at, verified against the recorded miss it came from
family: toolchain
created: 2026-10-02
---

*Walker context — the recurrence that earned this frame. On 2026-10-02 a
session verified `koru-libs/metal` by running `zig build` inside a
koruc-emitted scaffold. The run passed — and proved nothing: it recompiled
the already-emitted `output_emitted.zig` and never touched the compiler. No
refusal fired, so the miss is invisible to the friction corpus by
construction: `028` mines episodes where koruc **said no** and the message
failed to teach. This frame mines the episodes where nothing ever got to say
no — the scaffold that looks like a Zig project, the artifact that never
names its generator, the verb that exists but is never printed where the
wrong verb is invited.*

*The two frames are halves of one instrument: refused-and-unteaching versus
never-refused. Together they are how "the compiler teaches as you go" stops
being a hope and becomes a measured property — the fleet's agents carry no
Koru in their weights, so every miss a surface could have prevented is a
surface that should teach.*

---

## The brief (sealed — you are the contestant)

The harness has two miss corpora. Read both:

- **The refusal corpus** — `python3 friction/friction.py hist` (systemic:
  `--without org:COCPORN,repo:ogun`), then `lookup <code>` for teach-miss
  rows whose fix wanted to live *outside* the error message: the agent kept
  reaching for a surface that never pointed at the right one.
- **The silent-miss trail** — session transcripts (`prose grep`) for wrong-tool
  episodes that produced no refusal at all: `zig build` run by hand in an
  emitted scaffold, a big module `cat`ed where `koruc <file> glance` prints
  the whole surface, hand-greps for declarations a `koruc` verb already
  enumerates. A silent miss is any episode where a surface the agent was
  already touching could have taught the right move and didn't.

Pick **one** surface. Make it teach — at the point of use, nowhere else:

- The teaching lives **in the output the mistaken agent already sees**: an
  emitted header, a diagnostic line, a CLI usage block, the scaffold file
  itself. A doc the agent would have had to seek is a failure of the brief,
  not a variant of it.
- **Budget: one line, ~140 characters.** A second line only if it names the
  command. The constraint is literal — every token a surface adds is paid by
  every future reader, so the teaching earns its bytes or it doesn't ship.
- The fix lands **in the emitting surface** — the generator in `src/`, the
  CLI's own output, the message site — never in a consumer file. Editing a
  scaffold's checked-in copy teaches one checkout; editing the emitter
  teaches every emit forever.

Verify, don't narrate:

- **Mechanical:** the teaching string is present in the regenerated output —
  re-emit, grep it, quote it.
- **Episodic:** name the recorded miss this came from (corpus row or session
  id). A teaching invented from a hypothetical miss is speculative
  instrument-building — banned by the doctrine this frame serves. If you
  cannot point at a real miss, the surface doesn't need teaching yet.
- Where feasible, dry-run the miss path: follow the route the mistaken agent
  took and confirm the teaching is encountered *before* the wrong verb is
  reachable.

Self-ground before you build: `friction/teachings.md` is the ledger — one
row per shipped teaching (`surface · the miss · the line`). Read it; if your
surface already teaches, pick another. Append yours when done. Variance
across replays is the metric — the catalog of taught surfaces is what grows;
any single line is one slice through it.

Done-gates, all mechanical: teaching present in regenerated output · ≤ 140
chars · seeded from a recorded miss · diff lands in the emitting surface ·
ledger row appended.
