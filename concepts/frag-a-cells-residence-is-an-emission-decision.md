---
type: belief
id: frag-a-cells-residence-is-an-emission-decision
provenance: k-sharp numeric-loop benchmark, 2026-10-05 — a "cannot" claim
  corrected by the no-variables property, then implemented and measured in
  the same session
ts: 2026-10-05
---

# A cell's residence is an emission decision, not a semantics (belief)

The first version of `tests/benchmarks/010_numeric_loop` ended with a
verdict that was confidently wrong: the generated loop did one
`ldr`+`add`+`str` per element on the accumulator because `total` is *named
module state* — "a memory cell by semantics, not a register. The language
cannot emit the register-resident shape." The claim had the right shape —
it blamed a semantic instead of an emission — and was wrong anyway.

**No variables means no hidden accessors.** The reason a C# compiler cannot
hoist `static long total` into a local across a loop is that it cannot
prove nothing else reads the field mid-region: reflection, another thread,
a call that reaches it behind a boundary — the accessor list is
unbounded, so the analysis must be conservative. Koru's accessor list is
bounded *by grammar*: there is no spelling for "touch this cell from
somewhere the compiler can't see." A cell's complete accessor list is the
program text. So the safety question that is undecidable in C — "can
anything observe this location between region start and end?" — is a
textual enumeration here, and the answer to it is what the emitter now
spends: buffer the handler body, find the cells it names bare, check the
gates (`return`, `=>` lambda, qualified mention, same-named declaration,
a callee whose impl touches the cell), and on pass materialize the cell
as a local with a single writeback.

The measured result, `run_event.handler` Tier1-OSR: a 7-instruction loop
with the accumulator in `x2` for the entire trip count — `sxtw; madd; add;
add; sxtw; cmp; blt` — and one `str` after the loop. Instruction-identical
to the `direct` handwritten register loop that was previously declared
unreachable. The "residual" was an emitter gap the whole time.

**The general claim:** in Koru, *where a value lives* is never part of its
semantics. Residence — register, stack slot, static field, pool slot — is
a choice the emitter makes per region, and the cost of a choice is what
the gates couldn't prove, not what the language requires. When a
benchmark shows a gap between generated and handwritten code and the
explanation is "the semantics need it," that explanation is the thing to
disprove first. The prime-sieve already demonstrated the same property
buying whole-program wins (sweep-direction alternation, +19% over Rust)
from the same source: complete access knowledge, no hidden aliases.

**The mistake pattern to recognize:** reasoning about Koru as if its cells
were C variables — importing the host's aliasing limits into a grammar
that has no spelling for them. "Cannot" claims about emission deserve the
same bar as "can't" claims about the language: name the gate that would
refuse, or mark it unproven.

Related: [[frag-a-reference-emitters-shape-is-an-accident-of-its-host]] —
that belief is about porting a *shape* from a lax host; this one is about
mistaking a host's *limits* for the language's. Both reduce to the same
discipline: the strict facts live in Koru's grammar, not in whatever the
reference emitter happened to emit.

## What would correct this belief

A cell whose access set genuinely isn't enumerable — e.g., a resuming
continuation stored across an event boundary that reads the cell on an
unknown later resumption, or a `dynamic`/reflection path in host text that
the registry can't see. The current gates already treat both as
conservative drop-outs (lambdas refuse, opaque callees refuse); a case
where even that isn't enough would weaken "complete by grammar" to
"complete except where host text hides it."
