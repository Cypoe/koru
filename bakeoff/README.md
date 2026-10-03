# bakeoff — the catch-layer matrix

Same naive bug, four stacks, one question: **where does the mistake get
caught?** Every cell under `cells/` is buggy by construction — the verdict is
not *whether* a toolchain refuses but *which layer does the refusing*.

```
./run.sh          # regenerates the matrix + verbatim logs under out/
```

Verdict tiers, strongest first:

- **refuse (compile)** — the toolchain stops the program before it runs.
- **refuse (runtime)** — it builds, and the mistake surfaces only when executed.
- **ships (silent)** — builds and exits 0; the bug ships with the binary.

Scope rules, declared up front:

- **Naive programs only.** Each arm is what a competent developer writes by
  default — no hand-rolled typestate, no `Drop` guards, no linters-as-oracles.
  Discipline can approximate some of these refusals elsewhere; "be disciplined"
  is not a conversation. (The 2104 family in `910_LANGUAGE_SHOOTOUT` carries the
  *best-effort* version — typestate, hand-written guards — and records what it
  still cannot refuse.)
- **Verbatim or it didn't happen.** Every row is backed by a log in `out/`;
  nothing is quoted from memory. Re-run at any HEAD.
- **The matrix audits us too.** A cell where Koru's conversation is weakest —
  e.g. `type_mismatch`, refused today by the Zig backend in emitted
  coordinates — stays in the matrix as an open finding until the fix lands.
  Precedent: shootout `2104_12/13` found the same wound once and closed it.

Lineage: this is the mechanized sibling of
`tests/regression/900_EXAMPLES_SHOWCASE/910_LANGUAGE_SHOOTOUT` — same doctrine,
runnable sources instead of verdict documents, wider bug classes, more arms.

Requires: `koruc` (KORUC env or `../zig-out/bin/koruc`), `rustc`, `dotnet`,
`go`. Missing toolchains fail their cells loudly, not silently.

Current matrix (regenerate; do not trust this copy):

| cell | koru | rust | csharp | go |
|---|---|---|---|---|
| use_after_send | refuse (compile) | refuse (compile) | ships (silent) | ships (silent) |
| use_after_dispose | refuse (compile) | refuse (compile) | refuse (runtime) | ships (silent) |
| tainted_input | refuse (compile) | ships (silent) | ships (silent) | ships (silent) |
| type_mismatch | refuse (emitted-Zig coords) | refuse (compile) | refuse (compile) | refuse (compile) |
