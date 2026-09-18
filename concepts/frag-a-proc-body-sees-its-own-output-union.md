---
type: belief
id: frag-a-proc-body-sees-its-own-output-union
provenance: koru-libs/odds — the Jev criteria map is reflected off the
  return union at comptime; the hook proved load-bearing enough to
  ratify (2026-09-18)
ts: 2026-09-18
---

# A proc body sees its own declared output union (belief)

An effectful `~proc` body splices into the event struct's `handler`, so
inside the body `@This()` names that struct and `@This().Output` is the
event's declared return union. `@typeInfo` over it enumerates branch
names and payload types at comptime; `@unionInit` constructs a branch
by reflected name.

The consequence: **the event signature is the single declaration of an
answer space.** A proc can derive "which branches are categories" (f64
payload) from the type itself and never spell a branch name — rename a
branch and every consumer of the reflection follows. Control branches
and category branches are the same declaration, distinguished by
payload type.

Pinned at `200_COMPILER_FEATURES/230_EMITTER/230_019`: a proc
enumerates its own f64-payload branches and `@unionInit`s the winner
by reflected name. The splice was emergent when first depended on
(koru-libs/odds); a change to it now breaks a test, not a consumer.

The reflectable surface is **field names + payload types only** — and
the field name turns out to be the metadata slot after all. The
emitter quotes a bracketed branch name verbatim (`@"bug: Bug
reports"`), so `[tag: description]` survives into `f.name` intact: a
proc splits on the first `:` and recovers a criteria key and its
description from the same declared string. Nothing declared twice,
no new syntax, payload untouched. Pinned at
`300_ADVANCED_FEATURES/350_PATTERN_BRANCHES/350_012` — the same
reflection, now asserting the text round-trips and the arm dispatches
by name equality. The slot the earlier draft said was missing was the
name itself.
