---
type: belief
id: frag-a-catch-unreachable-asserts-the-callees-whole-future-error-set
provenance: cs tranche PB-3 — a js/cs_lower filter refusal SIGABRT'd the
  backend via koru_std's `catch unreachable` on processTemplateProcs, 2026-10-05
ts: 2026-10-05
---

# A `catch unreachable` asserts the callee's whole future error set, not its current one (belief)

`koru_std/compiler.stages.kz:23` reads `tp.processTemplateProcs(...) catch
unreachable`. When written, every error the call could raise had a diagnostic
upstream or was impossible — so the catch was a reasonable annotation of
"render failures exit before they reach me." Then the `js_lower`/`cs_lower`
filters learned a new refusal (`UnsupportedBuiltin`, by design — a builtin
the target table does not know is a render failure). The error propagated
faithfully through seven correct frames — filter, `evalConstRhs`, `renderTo`,
`renderWithEnv`, `renderTemplateInvocation`, `maybeRenderPerCall` — and died
on the eighth, where `catch unreachable` converted a *diagnosable refusal*
into a SIGABRT. Measured on 230_006's `for|cs` bound: `attempt to unwrap
error: UnsupportedBuiltin`, no message, the compile killed by signal 6.

The failure is not that someone wrote `catch unreachable`. It is what the
spelling silently asserts: **no error the callee can raise, now or after any
future edit, deserves a diagnostic I haven't already built.** Error sets are
open in practice — a callee deep in the pipeline acquires new refusals as the
language grows surfaces (this one grew an entire backend). The assertion
holds at write time and rots invisibly, because nothing re-checks it when the
error set widens. And the crash it produces is the worst kind: it names the
*frame that assumed*, not the *refusal that happened* — the trace pointed at
`lowerCsInto` returning the error, which was the one correct line in the
whole path.

The fix pattern this landed: refusal exits install at the frame that owns
the location, not at propagation's end. The filter stashes the refused
builtin's name (`lower_diag`, twin of `field_list_diag`), and the render
catch — the frame holding the invocation's `SourceLocation` — emits a
located KORU120 diagnostic and exits *before* the error can travel upward
to the asserting frame. The `catch unreachable` keeps its job (a genuine
impossibility still crashes) but diagnosable refusals never reach it.

Adjacent to [[frag-rejecting-a-program-and-crashing-share-one-exit-path]],
not an instance of it: that belief is about a diagnostic that *fired* and a
crash report that talked over it — the shared exit path. This one is the
error never getting a diagnostic at all because an asserting frame decided
the refusal was impossible. Same family — the exit plumbing deciding what a
failure *is* — opposite poles: there the crash drowned the message, here it
replaced it.

## What would correct this belief

Evidence that the asserting frame is the right place for refusal exits —
e.g. a codebase pattern where errors intentionally bubble to a single
`catch unreachable`-adjacent dispatcher that converts them. If that exists
and scales, the stash-and-emit-at-owner pattern is over-engineering and
the discipline belongs at the boundary instead.
