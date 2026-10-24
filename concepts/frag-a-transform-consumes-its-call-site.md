---
type: belief
id: frag-a-transform-consumes-its-call-site
provenance: c-lane session 3 2026-10-12 — 400_210_c_concurrency_refuses
  flagged `!` but not `pump`; traced to the pump transform rewriting its
  flow wholesale before emission
ts: 2026-10-12
tags: [koru, transforms, c-lane, refusal, ast]
---

# frag-a-transform-consumes-its-call-site

A transform does not annotate its invocation — it replaces the subtree
the invocation was part of. By the time an emitter walks
`program.items`, `std/pump:create` is not an `.invocation` node with a
path to check; the flow that carried it has been rewritten into
synthesized machinery, and the call-site evidence is gone.

Consequence for anything that censuses the post-transform AST — a
refusal table, a coverage instrument, a witness pass: **a predicate
keyed on surface invocations under-reports silently.** The C lane's
concurrency axis checked `std.pump:*` paths on invocations and found
none in a program whose whole control flow was pump; it looked like a
traversal bug and was actually a fact about what survives.

What DOES survive, and is therefore census material:

- **Merged module_decls.** `import std/pump` is consumed as an
  `import_decl`, but the resolution leaves `module_decl` items named
  `std.pump` / `std.rings` / `std.threading` in `program.items`.
  Presence-scoped, not use-scoped — stricter, always sound.
- **Continuation kinds inside impl flows.** `!` effect arms ride the
  transform output into `impl_of` flows and stay legible — the
  resumable axis detects post-transform because the *kind* survives
  even though the spelling is gone.
- **Compiler marks** (`is_transformed_subtree`, `@pass_ran`) — provenance
  the pipeline already stamps, available to any census that wants
  transform-produced subtrees without knowing which transform made them.

The general rule: evidence an emitter may read is the set of things the
pipeline *produces*, not the set of things the user *wrote*. Any axis
that needs use-site precision about consumed syntax must be measured
pre-transform — in a pass, not in an emitter — or accept the
presence-scoped approximation and say so.

Evolved 2026-10-12 (session 4): the same production-side reading is now
also the *eligibility* signal, not just the detection signal. A `!`
continuation whose parent invocation (or flow) carries `inline_body`
was dispatched by a template — it is transplant vocabulary (`for`s
`! each`), not a resumable pair, and the C lane's resumable census
walks past it. `inline_body != null` IS the census's test for "the
transform consumed this call site": cheap, structural, and it asks the
pipeline's own product rather than re-deriving which transform ran.
Deliberately not inherited past the direct parent — a nested event's
`!` arm inside a rendered arm is governed only by its own invocation.

Evolved 2026-10-14 (session c-lane rung 12, ~capture): two more
production-side facts.

- `flow.preamble_code` is the dissolving transform's second marker —
  the head invocation SURVIVES as an annotated husk (`@pass_ran`, same
  path/args) while the preamble text is what the site lowers to. The
  zig lane's contract is literal replacement (visitor_emitter.zig:3635);
  the C lane needed the preamble split two ways — file-scope by default
  (`const|c` static decls), statement-scope under `//@koru:stmt_scope`
  (~capture's per-call cell). An emitter that emits the preamble AND
  still walks the husk gets a `NoCProcBody` on a call that no longer
  exists — the preamble check must come first.
- Consumption is not total: `auto_discharge_inserter` grafts
  `node == .terminal` tombstones for declared-but-absent OPTIONAL arms
  (`| ?captured`) *after* the transform consumed them — a named arm
  reappears on the dissolved site carrying a no-op node. A census
  keyed on named arms over-reports; a dispatch emitter keyed on named
  arms refuses a dispatch that by construction fires nothing. The
  honest test is `node == .terminal`: the inserter's own marker for
  "this arm is the absent-optional no-op" — skip it, and keep refusing
  any named arm with a real body.

Evolved 2026-10-24 (session c-lane rung 15, nested ~capture): the
preamble-replaces-call contract has TWO channels, and the marker — not
the channel — is the contract. At flow level a dissolving transform
leaves `flow.preamble_code` beside the `@pass_ran` husk. At a NESTED
site (capture inside `| _`'s arm, or inside an outer capture's `! as`),
transform_pass_runner migrates the preamble onto an `.inline_code` node
and drops the husk itself — same semantics, different envelope. An
emitter that learned the flow-level shape alone emits the nested
preamble verbatim and never registers the cell: `.assignment` targets
fail "names no declared capture cell" even though the declaration text
was emitted two lines above. The `//@koru:stmt_scope` marker is the
production-side evidence both channels share — keying on it rather
than on where the text arrived is what makes nested capture the same
contract as top-level capture instead of a second implementation.
