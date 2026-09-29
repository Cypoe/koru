---
type: belief
id: frag-a-minted-compiler-is-a-sanctioned-pipeline
provenance: compiler-mints session 2026-09-29 — mint/use/check landed in src/main.zig over the compiler:requires seam; the aerospace sanctioned-profile use case is Lars's stated motivation, not speed
ts: 2026-09-29
tags: [koru, mints, coordinate, governance, closure]
---

# A minted compiler is a sanctioned pipeline, not a cache (belief)

Koru's pipeline is deliberately malleable — `std/compiler:coordinate` is an
`[comptime|abstract]` tor any program or imported module may override wholesale.
That malleability is the feature and the objection at once: an organisation
that must certify its toolchain cannot accept "the program decides how it is
compiled." The mint is the answer, and its purpose is **governance, not
speed**: shape the pipeline (drop passes, insert audit passes, remove
uncertifiable features — the override is a program-level one-liner), mint it
into a named artifact, and require programs to compile against it.

Three bindings, three different mechanisms — "compiled by the compiler we
sanctioned" becomes checkable:

- the override **shapes** the pipeline (`coordinate` is the surface);
- the mint's coverage predicate **binds artifact to shape** — the closure key
  is the emitted backend's content, so a mint cut under an override refuses a
  program whose pipeline differs (verified: an override alone moves 56 emitted
  lines);
- `hash:` **binds program to binary** (sha256 of the stored artifact);
- `mint check` **binds artifact back to the tree** — the valid-vs-stale
  distinction is deliberate: a mint may still cover a program while its source
  tree drifted, and the audit reports that separately rather than conflating
  "cannot serve this program" with "no longer represents HEAD".

Two discipline rules the implementation surfaced:

- **A selector must never enter what it selects.** `use` is a comptime-typed
  directive, so the naive path swept the mint NAME into the closure hash and
  `use(a)` vs `use(b)` read as different compilers. The directive is
  frontend-only: collected, then stripped from the AST before emission.
- **Coverage must normalize non-semantic provenance.** The emitted backend
  carries `file:line` comments; hashing raw bytes pinned each mint to the
  literal filename it was minted from. Comment-stripped hashing is what makes
  a mint reusable across programs at all.

Honest limits, kept on purpose: `use` pins backend stages only — the invoked
`koruc` still runs Stage A, so a fully pinned toolchain wants a versioned
driver; `hash:` verifies name→binary against sha256 + filesystem trust (no
signing yet); mints are target-locked; and `use` is a commitment the program
makes — enforcement for programs that don't commit is packaging policy, not
the directive's job.

Falsifiable edges: if the closure hash ever stops capturing the coordinate
override, imported comptime modules, or baked command dispatch, coverage is a
lie and this belief is wrong. The pin is 220_048 (mint → use → hash →
coverage-refusal → check, all inside a sandboxed KORU_MINT_DIR).
