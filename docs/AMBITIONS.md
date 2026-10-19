# Ambitions

Pinned: `072375a31` on `main`, measured 2026-10-18 (dirty tree — AGENTS.md,
CLAUDE.md, regression-ledger, one test input modified, uncommitted).

Large directions this repo is already pointed at, stated once and filtered to
what is actually ours to do. Each entry names what's already real, what the
work is, and what it deliberately is not. A scan, not a promise — re-measure
against the live tree before spending a session on any row.

---

## A1 — The Koru corpus is the source of truth (host-realization independence)

**Ambition.** The compiler's semantics live entirely in the Koru corpus. The
host — Zig today — is a realization detail that can be swapped without
changing the chosen observations: emitted bytes, diagnostics, verdicts.

**Already real.** The pipeline is orchestrated in Koru —
`std/compiler:coordinate` is a `[comptime|abstract]` tor, program-overridable,
and mints bind artifact→shape→tree by closure hash (pin 220_048). The AST
already crosses Stage A→C as encoded data: `program.ast.json` deserialized
onto the backend arena. A runtime evaluator exists (`std/interpreter`,
~5.7K lines — see the park note below). `std/parser` already runs the
partial-evaluation idiom in miniature — its comptime codegen is, per its own
header, "a PARTIAL EVALUATION of the common static shape."

**The work, in dependency order:**

1. **AST-as-data.** Passes today receive `ctx.ast` as the Zig `Program`
   struct — a privileged host type. The encoded crossing exists; what does
   not is an environment interface where a pass sees the artifact as
   Koru-visible data. This is the precondition for everything below.
2. **Passes as ordinary Koru tors.** The orchestration tors exist; their
   bodies are `|zig` procs `@import`ing `src/` modules — `emit-zig` alone
   rides `emitter_helpers.zig` (14.7K lines) + `visitor_emitter.zig` (5.5K);
   the checkers add ~10K more (phantom 5.2K, shape 2.7K, flow ~2.8K);
   the frontend parser is 12.8K. This is where the mass is.
3. **coordinate and target selection as context data.** Both surfaces
   already exist (abstract tor, proc variants `|zig`/`|js`/`|cs`, `--lang`,
   the command surface). The move is consolidation into realization-spec
   data — inspectable rather than only hash-bound — not invention. Known
   bug class to respect: a selector must never enter what it selects (the
   `use` directive had to be stripped before closure hashing).
4. **A minimal evaluator/loader seed outside Koru**, small enough to audit.
   Note the collision: challenge 014 records the runtime/interpreter family
   as **parked pending Lars's decision**. The seed question and the park
   decision are the same question — this item does not start while the park
   stands.
5. **Recover production the boring way**: the seed interpretively runs the
   corpus once to emit the compiler's own target code (one slow boot), then
   retires to loader. Explicitly **not in scope**: a Futamura-style
   specializer as a built artifact — that is a research program, not a
   refactor, and nobody has scoped it. If "specialize" ever appears in a
   plan, it means the slow boot unless Lars says otherwise.
6. **The honest form of "proof"**: a gate row that A/B-compiles the same
   corpus under both realizations and diffs the chosen observations — the
   verdict-equivalence protocol already proven on challenge 030's gate.py
   replay. `invariants/` rows are checks and sampled alarms, not proofs;
   the ambition names an instrument, not a theorem.

**What it is not.** A rewrite of `src/` for its own sake. Each move lands
only when verdict-equal on the corpus — same emitted bytes, same
diagnostics, same verdicts — per the established done-bar.

---

## A2 — The host floor is earned-only (`|zig` → pure Koru, project-wide)

**Ambition.** Every `|zig` / `|js` / `|cs` proc body that is not an honest
effect boundary becomes an ordinary Koru body. The economics are the
attraction: today one tor carries a body per host target — a pure-Koru impl
replaces all of them at once (target-collapsing).

**Measured today.** 333 `|zig` + 33 `|js` + 17 `|cs` proc bodies in
`koru_std/`. The host layer is the stdlib's actual mass — first host-board
pin measured it at ~15x the decl census (`deslop-stdlib-host-board`).

**The split that matters.** Two classes, one count:

- **Earned host** — `io`, `fs`, `net`, `threading`, `crypto`, allocators:
  the FFI/effect surface. Stays host by design; this is the facet's point.
  A `.kz` carrying real host items is correct, not debt.
- **Unearned host** — compiler and computation logic written in Zig because
  no Koru surface existed when it was written. The chip target is this
  class, and this class only.

**Blockers and free moves.** Compiler-path bodies that touch `Program` are
blocked on A1.1. Non-AST, non-FFI bodies are chippable now — but "which of
the 333 is which" is unmeasured, and that census is the first cheap
instrument, not a port. **Standing floor: never zero.** Success is the
earned class holding everything that remains.

**Adjacent instruments already standing.** Challenge 032 (facet sweep)
censuses convertibility and stops at the earned boundary — it classifies
files, never reduces host mass. Challenge 030 (last interpreter) retires
*external* interpreters in the enforcement path, not in-language host
bodies. No challenge currently owns this direction.
