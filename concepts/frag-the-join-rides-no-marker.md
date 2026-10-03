---
type: belief
id: frag-the-join-rides-no-marker
provenance: 400_205 — `|> for … ! each … |> <join>` parsed the join into the
  AST and emitted nothing for it; an obligation written onto that tail leaked
  undiagnosed. Found by the probe matrix seeded from the related-posts
  benchmark's obligation shapes
ts: 2026-10-03
tags: [koru, emitter, continuation, join, template-markers, effect-branches]
---

# The join rides no marker (belief)

A template hands off to a *named* arm through `{{ continuations["X"].continue }}`
— the marker resolves by branch name. An anonymous continuation is the
construct's join, and it has no name: no marker can address it, and no marker
will ever exist for it. Any emission path whose model is "emit the template,
arms arrive through markers" therefore drops the join in silence.

This is the emitter-side twin of
`frag-a-synthesized-arm-appended-past-the-join-reads-as-the-leaf`. That ruling:
list *position* is the join's identity — positional readers mistake a named arm
appended past it for the exit. This ruling: *name* is the arm's identity — the
join is precisely the continuation the marker mechanism cannot see, so every
marker-driven path must ALSO append the anonymous tail as a loose body. The two
together say the same thing from opposite ends: the join is real code that no
arm-machinery (name or marker) reaches; it is carried only by the list's
anonymous tail, and every consumer of that list owes it an explicit emission or
disposal decision.

The defect signature that marks this belief's territory: a program that parses
correctly, emits a silently truncated path, exits 0, and produces no diagnostic
— the worst outcome class, because the user's written code vanished between AST
and machine. When a join tail carries an obligation-disposal step the leak is
also undiagnosed, because the discharger believed the emitted code contained
what the source wrote.

The standing rule for future paths: partitioning continuations into
effect/terminal/arm buckets is fine — but the anonymous partition is not a
residue to discard with `_ = &…`, it is the caller's chain resuming. `emit`
it after the construct, in order, or the construct eats its caller's tail.
