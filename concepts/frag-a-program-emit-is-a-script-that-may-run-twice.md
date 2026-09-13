---
type: belief
id: frag-a-program-emit-is-a-script-that-may-run-twice
provenance: 2026-10-12 — asteroids/ponkatris on korulang_org: an SPA revisit re-mounts
  the page's <script> and the second eval died at parse time with
  `Identifier '__koru_len' has already been declared`
ts: 2026-10-12
tags: [js-target, emitter, browser]
resource: src/js_emitter.zig (emit)
---

# A program emit is a script, and a script may run twice (belief)

The JS emit's top level is not a module scope. When the page loads it as a
classic `<script>`, every top-level `const`/`let` lands in the SHARED global
lexical environment — the one environment all classic scripts on the page
write into. A second evaluation of the same emit (SPA route unmounted and
remounted, a harness that evals twice, a hot-reload) meets its own prelude's
declarations already standing and fails at PARSE time — before a single
statement runs — with `Identifier '…' has already been declared`.

This is a property of the artifact, not of any call site: `vm.runInThisContext`
in Node reproduces the shared-lexical-scope semantics exactly, which is how
the crash was pinned without a browser.

The ruling: a program emit wraps in `(() => { … })()` so each evaluation gets
a fresh scope; a facet that must publish does it through `window` explicitly.
Libraries stay unwrapped — their output is ESM (`export`), which cannot live
inside a function scope and never needs to: the module loader dedupes.

The deeper shape this is an instance of: the emit's contract is the HOST's
loading semantics, not the language's. "It compiled and ran once" is not
evidence the artifact is sound — the host environment gets a second vote.
