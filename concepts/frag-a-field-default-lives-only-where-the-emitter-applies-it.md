---
type: belief
id: frag-a-field-default-lives-only-where-the-emitter-applies-it
provenance: introduced by the PARSE011 tightening (challenge 024 replay 5) — branch payload field defaults silently dropped
ts: 2026-09-24
---

# A field default lives only where the emitter applies it (belief)

`= <expr>` on a shape field means "the emitted Zig struct carries this
default". The shapes where a consumer applies it: the tor **input**
shape, which becomes the `Input` struct (400_185, 400_186 pin the
splice), and `-> { ... }` record returns, where the default lands on the
Output struct verbatim and Zig applies it. Branch payload shapes are the
exception that proves the rule: `| next { v: i64 = 5 }` parses the
default into `Field.default` and then the emitter drops it — a
constructor that omits the field dies in the backend on `missing struct
field` despite the declaration, and `| ok i64 = 5` leaks `= 5` into the
union as enum-value syntax (`missing integer tag type`).

So the law is jurisdictional, not about the text: **a default is legal
only where a consumer applies it.** The parser (`parseBranchPayloadShape`
and the identity paths of both branch parsers) refuses `= <expr>` on
payload surfaces with PARSE011, caret on the branch line; 210_265 and
210_266 pin it. Calls inside the input-field default are separately
illegal (KORU104, the expression-admission wall — 210_263/264), but that
is a different rule about the default's *contents*; PARSE011 is about the
default's *existence* on a surface that drops it.

Open edge: record *input* shapes nested inside input fields
(`{ r: { x: i64 = 1 } }`) — the nested default is emitted into the
nested struct literal, where it does apply; whether parseShape reads it
back out is unmeasured.
