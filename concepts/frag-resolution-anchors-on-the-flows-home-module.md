---
type: belief
id: frag-resolution-anchors-on-the-flows-home-module
provenance: fixing 115_012, the parser mirror; the grammar lookup was the visible fault and the wrong anchor was underneath it, invisible until the lookup was fixed
ts: 2026-08-02
---

# A name resolves against the module it was WRITTEN in, never against the program's main module (belief)

Two faults sat on top of each other in `[with]` vocabulary resolution, and the
second only became visible once the first was gone. That stacking is the durable
part; the pass is the occasion.

The first is the one the 115 wall was built to find: a walk over
`program.items` that never descends through `.module_decl`, so the pass simply
does not visit a flow that lives in a library. Known class, gardened already,
and cheap to fix once seen.

The second is the interesting one. The pass asked *"is this name stamped with
the main module?"* as its test for "is this an unqualified name I am allowed to
restamp." In the entry file that question is correct by accident — the file's
derived name, the import-derived logical name and `main_module` all collapse
into one word. In a library it is simply the wrong question, and it fails
CLOSED: every bare name in a library flow reads as *already qualified, not
mine*, and the pass declines to touch it while walking straight over it.

**The anchor for "unqualified here" is the flow's HOME module.** Canonicalize
stamps a bare name with the module it was written in; the resolver has to ask
against that same module or it is comparing two different domains. `main_module`
is not a synonym for "here" — it is only ever "here" for one file in the
program.

## Why this is worth writing down rather than just fixing

A descent fix looks complete when the walk reaches the node. It is not complete
until every value the walk *carries down* is re-derived at the new depth. A
walk that descends but keeps passing the top-level's notion of "here" has
traded a silent skip for a silent no-op, which is strictly harder to see: the
pass now runs, reports nothing, and changes nothing.

So the check on any descent fix is not "does it visit the node" but "what did
this function believe about its position, and is that belief still true one
level down." Here the belief was one string parameter.

## The fault shape it produces downstream

Neither fault reported itself. The diagnostic the author actually read was
`std/parser:parse` refusing the grammar's own picker as "not the static
`std/parser:match(<cursor>)` shape" — a wall firing correctly on a path it was
handed unresolved. A refusal three layers from the fault, phrased with total
confidence, and blaming the author's source.

That is the second time this area has produced a diagnostic that names the
author's code for a fault in the machinery
([[frag-transform-module-exposure-is-not-one-fault]] carries the first). It is
worth suspecting the phrasing of any wall that fires only when the subject
moves into a module.

## The same shape one layer over: routing by item kind fails OPEN

`std/kernel:init` had the identical anchor bug — it minted its synthesized init
tor under `flow.module` and the program went looking for `lib:kernel_init_…`
with the declaration sitting in plain sight under `app.lib`. Fixing the anchor
made the name resolve and the build still failed, because a NAME resolving and
a DECLARATION being reachable are two different things.

The transform runner routes appended declarations into the module they address
themselves into. It reads that address off the item, and the reader is a switch
over item kinds with `else => null`. A kind absent from that switch is not an
error and not a refusal: it silently keeps top-level placement. `host_type_decl`
was the absent kind, and it was absent for a reason that reads as a decision —
it was the one appendable item carrying no path, no location, and no module, so
there was nothing to route it ON.

So the type emitted into the entry struct while the code naming it emitted into
the library's struct, and Zig gives a sibling struct no path to the entry
struct. Position in the item tree is what the emitter and the host-type-home
registry both read; the item had no way to earn a position.

**A dispatch table over a closed set of kinds is a wall with a default-allow.**
Every kind it does handle is evidence someone hit that case in production; the
kinds it does not handle are not "cases that cannot arise" — they are cases
nobody has hit yet, wearing the same silence. Adding the field the item was
missing is the fix; the durable part is knowing that the `else` arm of a routing
switch is a placement decision, not a no-op.

## Open

- ~~Whether other passes carry `main_module_name` as a stand-in for "here".~~
  **Measured, 2026-09-18: phantom-state canonicalization does — and it carries
  two different anchors inside one file.** A `.kz` param declaration tracks
  `*Handle<live>` under the file's DERIVED name (`m:live`); the call site
  checking that same value expects the import-derived LOGICAL name
  (`app.m:live`). One spelling, one file, two state identities — the same
  "two different domains compared" shape as the `[with]` anchor bug, one
  organ over. A subflow that re-passes its own phantom param to a same-module
  tor is refused (`expected 'app.m:live' but got 'm:live'`); union-state
  `<a|b>` params and `@label` re-entry fail the same root, and KORU032's
  scope-discharge block means a module-internal loop over phantom args cannot
  be written at all. Pinned RED as `330_134`; the entry file's derived/logical
  names collapse into one word, so only library modules expose the fault —
  the same reason the `[with]` bug hid until a flow moved into a library.
  **Resolved, 2026-09-18:** the anchor the seed should have used was already
  in hand — the module component of the `event_map` key the implementing
  event was found under, the same `event_module orelse event_decl.module`
  pattern the checker already used at its own resolution sites. `impl_ev.module`
  (the parse-time stem) was the wrong fallback order: it should answer only
  when no resolution key exists. The `@label` jump had the identical bug one
  switch arm over — it validated against `decl.module`, now against the
  registration module. Union `<a|b>` params were also never seeded at all —
  a union param is now tracked as its union state, so union→union re-pass
  satisfies while union→concrete still correctly refuses. `330_134` is green;
  a `#round` fold over a phantom judge inside a `.kz` module now compiles and
  runs.
- Whether "home module" wants to be a field on the flow rather than a parameter
  threaded through every walk. A parameter is one refactor from being wrong
  again; the flow already knows the file it came from. The `330_134` fix grew
  the count — `impl_module` is yet another parameter threaded where the found
  key already knew the answer.

Measured again, 2026-10-09 — same anchor, new organ, five more sites.
`std/channel`, `std/rings`, `std/pump` and `std/supervisor` each minted
synthesized `module_qualifier`s off `flow.module` (the file-derived name)
while every parsed decl carries the import-derived logical name — 115_050
through 115_053 read `unknown tor 'lib:__channel_recv_inbox'` /
`'lib:__ring_feed_enqueue'` / `'lib:__pump_run_main'`, the kernel-init fault
verbatim, one stdlib organ over. And each module had grown its own private
copy of the walk that derives the logical name, plus the containing-flow
walk a site *view* needs (the runner hands a transform a synthetic flow;
`site_of` is the only path back to the real tree). Five copies of one
belief is the parameter-threaded shape this frag already flags — the walks
now live once in `src/ast_functional.zig` (`moduleHome`, `containingFlow`,
`findEventDecl`), and `.module` fields keep `flow.module` because that is
the emitter's routing key, not a name anybody resolves.
