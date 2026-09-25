---
type: belief
id: frag-with-declares-the-flows-vocabulary
provenance: "[with] tightening conversation, 2026-09-25 — the odds inbox
  example exposed ~23 redundant qualifiers; the ruling resolved greppability
  against brevity by making the open set a declared thing"
ts: 2026-09-25
tags: [koru, with, vocabulary, resolution, annotations, ruling]
---

# `[with]` colors a whole flow, and the open set is declared, not derived (belief)

`[with]` is not lexical scope. It never was: the resolver gathers every opener
in a flow's subtree and then resolves every bare name in that same subtree —
position carries no meaning. An opener nested three arms deep reaches the flow
head and its sibling arms. The extent is exactly the flow's text; nothing
crosses a flow boundary or a call boundary. The correct mental model is a
**coloring**: the annotation declares a property of the flow — its open
vocabulary — the way an impl belongs to an event. Lexical scoping would be the
larger feature (subtree-bounded gather, position-aware resolution) and buys the
one thing bounded lookup exists to prevent: a flow that changes dialect
mid-arm.

**The open set is spelled in the annotation.** `[with(std/io, koru/odds)]route =`
puts the whole vocabulary at the impl head where a reader and a grep find it —
the failure of the derived-only design was that the open set was smeared across
whichever calls happened to carry the tag, so local truth depended on body
ordering. Arguments are comma-separated like every argument list in the
language; `|` remains exclusively the annotation separator. An argument must
name a module the file already imported (KORU142) — the annotation abbreviates
a declared dependency and can never create one, which is also why aliasing is
unspellable: there is no name position that could carry a rename.

The bare `[with]` form survives as sugar — the module derives from the
annotated call — but it is the special case, not the primitive. `[with]` only
ever rides on a real construct (impl name, invocation, label); there is no
freestanding opener, which is what keeps the surface an annotation and not an
import statement wearing brackets.

**What the guards protect:** unresolved-only resolution means `[with]` can
convert an error into a resolution but can never rebind a working name — a
local `match` beats an opened one unconditionally. Ambiguity across opened
modules is a KORU140 wall naming every owner. Both survived the change
unmodified; what changed is that matching keys on the full dotted event name —
two modules exporting different `*.ln` events were colliding on a segment
nobody wrote (641_021).

**The frame this settles:** the qualify-everything instinct was defending
local truth, not qualification. Bounded lookup is the invariant; the flow —
not the call site — is the granularity at which a Koru region has a dialect.
Pins: the 641_010–021 cluster; the whole-flow extent specifically is
641_020.

## Open

- Whether the bare derive form should eventually be narrowed to explicit-args
  only. Kept for compatibility and for transform-anchored opens
  (`[with]std/parser:grammar` derives correctly because the anchor IS the
  module being opened).
- Whether a transform-owned region should resolve greedily — inside a subtree
  a plugin interprets as data, a local `match` shadowing `std.parser:match`
  resolves `main:match` and then the transform refuses its own verb as the
  wrong shape. Unresolved-only is correct for dialect regions (real dispatch)
  and arguably wrong for plugin regions (the subtree is the plugin's input).
- `[with()]` empty parens and `with(a|b)` inside the parens both parse as one
  annotation entry and currently fail only at module-validation — neither is
  refused *as syntax*, and the diagnostic doesn't teach commas.
