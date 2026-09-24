---
type: belief
id: frag-flow-location-is-the-head-line
provenance: the capture transform's KORU164 caret landed on the blank line after the flow because Flow.location meant "wherever the parser cursor happened to stop", and the answer differed by parse path; unified to head-line semantics 2026-09 (pins 210_255, 210_256), extended to ImmediateImpl the same week (pins 210_260, 210_261) — EventDecl was already head-line
ts: 2026-09-06
---

# An item's location is its head line — one coordinate, set once in the parser, never recovered downstream (belief)

`ast.Flow.location`, `ast.ImmediateImpl.location`, and `ast.EventDecl.location`
each have exactly one meaning: the 1-based line of the item's head — the flow's
head invocation (`tick = capture { … }`), the impl's `name -> …` / `name => …`
line, the `tor name` / `~[…]pub tor` line — with that line's indent as the
column.

Before this was enforced, each construction path recorded whatever
`getCurrentLocation()` returned at build time — and the cursor had already
consumed the whole item, so the same field meant "the head" on one path and
"the blank line after the last continuation" on another. Every diagnostic that
passed the location — hundreds of transform refusals in koru_std, the
flow_checker's impl diagnostics — inherited whichever meaning its parse path
happened to produce, and no consumer could tell which it was looking at.

## What follows

- **The parser captures the head line index before consuming the head.** Every
  construction site — normal flows, `name = event` impl flows (all three
  subflow paths), label-declared flows, every `->`/`=>` immediate-impl form —
  stores the head coordinate. There is no second field and no "which line did
  you mean" recovery step.
- **Downstream code never reconstructs the head.** A consumer that needs the
  step's line uses that continuation's own `location`. Walking a location
  backward, or adding a line to compensate, means the producer is lying — fix
  the producer.
- **Non-diagnostic uses get the same guarantee for free.** Generated names and
  dedup keys keyed on a head line (`__koru_cap_{d}`, `__koru_re_*`, grid sweep
  names, kernel hashes) are unique because two items cannot share a head line.
- **Head line and coordinate base are orthogonal axes.** Which line is pinned
  is this law; how the line is numbered is a separate, deliberate choice:
  flow/continuation/impl locations store parser (injected-buffer) coordinates
  that `ErrorReporter` and the AST serializer translate at the boundary, while
  declaration locations (EventDecl, procs) store user coordinates so a raw
  reader of `--ast-json` sees the author's line (the 210_164 pin). A consumer
  crossing between the two converts with `reporter.injection_line_count` —
  that conversion is bookkeeping, not drift, and a `±1` written as a bare
  constant is the smell this law exists to catch.

## Open

Continuation-only subflows (`~ev =` then `|` lines) name the declaring `~ev =`
line as their head — the synthesized pass-through invocation has no line of its
own, and no transform refusal can reach it (refusing steps are nested sites
that ride the continuation's location). Whether a caret there should prefer
the first `|` line is a UX question, not a semantics question.
