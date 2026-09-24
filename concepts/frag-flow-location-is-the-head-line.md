---
type: belief
id: frag-flow-location-is-the-head-line
provenance: the capture transform's KORU164 caret landed on the blank line after the flow because Flow.location meant "wherever the parser cursor happened to stop", and the answer differed by parse path; unified to head-line semantics 2026-09 (pins 210_255, 210_256)
ts: 2026-09-06
---

# Flow.location is the flow's head line — one coordinate, set once in the parser, never recovered downstream (belief)

`ast.Flow.location` has exactly one meaning: the 1-based line of the flow's head
invocation, with that line's indent as the column. For `tick = capture { ... }`
it is the line with `tick =`; for a bare `capture { ... }` flow, that line.

Before this was enforced, each construction path recorded whatever
`getCurrentLocation()` returned at build time — and the cursor had already
consumed the whole flow, so the same field meant "the head" on one path and
"the blank line after the last continuation" on another. Every diagnostic that
passed `flow.location` — hundreds of transform refusals in koru_std — inherited
whichever meaning its parse path happened to produce, and no consumer could
tell which it was looking at.

## What follows

- **The parser captures the head line index before consuming the head.** Every
  construction site — normal flows, `name = event` impl flows (all three
  subflow paths), label-declared flows — stores the head coordinate. There is
  no second field and no "which line did you mean" recovery step.
- **Downstream code never reconstructs the head.** A consumer that needs the
  step's line uses that continuation's own `location`; a consumer that needs
  the flow uses `flow.location`. Walking a location backward, or adding a line
  to compensate, means the producer is lying — fix the producer.
- **Non-diagnostic uses get the same guarantee for free.** Generated names and
  dedup keys keyed on `flow.location.line` (`__koru_cap_{d}`, `__koru_re_*`,
  grid sweep names, kernel hashes) are unique because two flows cannot share a
  head line — the post-consume coordinate could only collide by accident.
- **The translation axis is orthogonal.** `flow.location` still stores parser
  (injected-buffer) coordinates; `ErrorReporter` and the AST serializer convert
  to user coordinates at the boundary. Head-line semantics says *which* line;
  the injection shift says *how it's numbered*. Corrections for the shift
  (injection_line_count) and for other item kinds (ImmediateImpl, EventDecl)
  are a different law.

## Open

Continuation-only subflows (`~ev =` then `|` lines) name the declaring `~ev =`
line as their head — the synthesized pass-through invocation has no line of its
own. Whether a caret there should prefer the first `|` line is a UX question,
not a semantics question; the field's meaning is settled either way.
