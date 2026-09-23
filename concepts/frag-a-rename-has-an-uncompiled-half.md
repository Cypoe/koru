---
type: belief
id: frag-a-rename-has-an-uncompiled-half
provenance: the event→tor sweep, 2026-09-21 — the rename had landed in code (pub tor; transforms' own comments already said `tor` beside identifiers still saying `event`) while ~446 comment lines across 85 files still taught `event`, worst in koru-by-example.md — the file agents are pointed at first
ts: 2026-09-21
---

# A rename has an uncompiled half, and nothing enforces it (belief)

Rename a construct and the compiled half of the change is self-enforcing: every
site still spelling the old name fails to compile, so the code corpus converges
on the new vocabulary whether or not anyone sweeps it. The uncompiled half —
comments, docs, prompts, the by-example file every agent reads first — has no
such enforcer. It keeps teaching the dead word indefinitely, to humans and to
every model that loads it as context.

Measured: the event→tor rename had been landed long enough that in
`bridge.turn.kz` the prose already said `tor` on the same lines where the
identifiers still said `event`. The residue was ~446 comment lines in 85
files, concentrated where it does the most damage — the canonical syntax
oracle. The failure is not stale text; it is *recursive* staleness: an agent
reads the canonical file, emits the dead word, and the dead word lands in
fresh prose and fresh design docs with borrowed authority. That is exactly how
the residue was found — a generated document taught a construct called `event`
months after the construct stopped being called that.

**The fix shape follows from why it drifts.** Prose cannot be compiled, so it
must be gated: a one-time mechanical sweep for the residue — with the
code/text mask of
[[frag-a-textual-substitution-over-source-needs-a-code-mask]] applied by hand,
denying identifiers, generated names, domain events, and quoted history — and
then an `std/invariants:inferred` row so only *new* prose can regress. The
gate is diff-scoped precisely because the backlog is real: internal
vocabulary (`EventDecl`, `event-denied`, emitted `_event.handler`) and
diagnostic strings still say `event`, deliberately — a rule broad enough to
fire on them would be wrong
([[frag-a-rule-inferred-from-one-failure-is-too-wide]]).

**Open:** the internal vocabulary itself. Compiler identifiers and emitted
names still speak `event`; that half IS compiled, so it cannot drift — but
the tree now teaches two nouns for one construct, and the prose gate can only
tell them apart by the boundary list baked into its rule text. Whether the
internals follow the rename is a ruling, not a sweep.

Related: [[frag-a-migration-cannot-be-verified-on-what-it-migrated]] — the
sibling failure: a rename verified against the population that moved while an
unenumerated population kept the old name. There the unenumerated population
was the admission list; here it was every uncompiled word.
