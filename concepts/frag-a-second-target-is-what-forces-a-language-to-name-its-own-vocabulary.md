---
type: belief
id: frag-a-second-target-is-what-forces-a-language-to-name-its-own-vocabulary
provenance: the JS port of std/store's query guard and std/kernel's op body — three symptoms that turned out to be one cause, and a vocabulary that was already written on exactly one side
ts: 2026-08-07
---

# A single-target language never has to say what its operations are; the second target is what makes it (belief)

Koru writes `@sqrt(x)`, `@mod(a, b)`, `@as(i64, v)` in ordinary expression
positions. For as long as Zig was the only target, nobody had to decide whether
those were **Koru operations** or **Zig builtins leaking through a hole**,
because the question had no consequence: Zig accepts them, so passing them
through is indistinguishable from understanding them. The Zig emitter passes
essentially every expression through verbatim, and that is not laziness — it is
the correct implementation of "the host spelling is the spelling" — but it is
not COMPLETE, and the counterexample was measured on 2026-08-07: `==` on two
strings. Koru's `==` on strings is value equality — the comptime fold
(`comptime_eval.zig` folds it with `mem.eql`), the interpreter, and the JS
target all already agreed — and Zig has NO verbatim spelling for that:
`[]const u8 == []const u8` is a compile error. Pass-through was not
"understanding by coincidence" there; it was a raw Stage-D leak ("cannot
compare strings with ==") refusing a program three other organs of the same
compiler considered meaningful.

JavaScript cannot do that. `@sqrt` is a syntax error, `and` is a syntax error,
`x << 32` is a no-op rather than an error. So the JS emitter had to enumerate the
operations it understood and **refuse the rest** — and an enumeration plus a
refusal is what a definition IS. The vocabulary of Koru's `@`-operations was
therefore written, in full, on the JS side and nowhere else, as a consequence of
porting rather than as an act of language design.

**The general claim:** a language with one backend cannot discover its own
surface, because every question it might ask is answered by default. The second
backend is not merely a port — it is the instrument that makes the surface
observable, and the first place its definition appears will be the side that
could not pass anything through.

## The three symptoms were one bug, and none of them was a missing feature

A `std/store` query guard reached `node` as `hp > 40 and kind == 1`. A
`std/kernel` op body reached it as `@sqrt(dsq)`. Both read as gaps in the
language. Neither was.

`js_emitter` had mapped `and` to `&&` and `@sqrt` to `Math.sqrt` for months. The
lowering was reachable **only from text the emitter itself wrote**, and every
other route an expression takes to a host — a transform splicing a guard into a
proc body it assembles, a kernel op body pasted into a generated loop — carried
it past the pass untouched. Three symptoms, one cause: *text that never reaches
the one thing that knows how to lower it.*

The corrective worth keeping: **`@sqrt` was on a list of things needing a design
ruling, and it never needed one.** A missing lowering and an unreachable lowering
present identically at the failure site, and the difference is invisible unless
someone greps the emitter for the operation's name. Before booking a symptom as a
language gap, check whether the answer already exists somewhere it cannot be
called from.

## Where the definition lives now, and what is deliberately still open

The pass is `codegen_utils.lowerKoruExpr`; the vocabulary is `lowerBuiltin`
beneath it. `js_emitter` is now one of its callers rather than its owner, and so
are `std/store` (guards) and `std/kernel` (op bodies).

**RULED (Lars, 2026-08-07): the Zig spelling stays the Koru spelling for now, and
the exact shape of the vocabulary is deliberately not settled.** The reasoning is
the load-bearing part: the shape is cheap to change once there is *one home* for
it, and expensive to argue about while there are two. Getting something in place
that has a relationship to a vocabulary beats getting the vocabulary right.

So the `.zig` arm is the identity **for the vocabulary** — with two semantic
carve-outs it now carries:

- 2026-08-07: a literal-grounded string `==`/`!=` rewrites to
  `@import("std").mem.eql(u8, …)`, because that operator's Koru meaning has no
  verbatim Zig spelling at all (see above).
- 2026-09-17: `%` rewrites to `@rem(lhs, rhs)`. Zig's `%` is **unsigned-only**
  (`signed integers and floats must use @rem or @mod`), while Koru's is C's
  truncated remainder — what `comptime_eval.zig` folds it with (its own comment
  calls `@rem` "the C-parity choice") and what the JS target's `%` already was.
  `n % 2` compiled on JS and died on Zig; again every other organ agreed and the
  Zig emission leaked the host's error.

These rewrite nothing the language already had; they make programs run that
every other organ accepted. The distinction worth keeping: *identity is a sound
default where the host shares the semantics, and a silent leak where it does
not* — "comparison is shared" was true of every comparison except the one on
strings, and "arithmetic is shared" was true of every arithmetic operator except
the one the host had narrowed.

The second carve-out is the more instructive one, because it is invisible to
reading: `%` is the SAME GLYPH on both sides, so nothing in the text looks
wrong — the host simply defines it on a smaller domain. `==` on strings failed
loudly in a shape Zig has no operator for at all; a same-glyph operator with a
narrower domain looks like agreement until a signed operand arrives. A glyph
being spelled the same in both languages is not evidence that the same operand
types are accepted, and it is the operand-type condition, not the spelling, that
identity is really claiming.

What the ruling still defers, stated plainly because the whole point of writing
it down is that it not go invisible: **the vocabulary is enforced on JS and
absent on Zig.** A `.k` naming an `@foo` nobody modelled is accepted by one
target and refused by the other, so the table can drift into "whatever JS
happened to need" rather than "what Koru means" — which is
[[frag-a-wall-guards-one-direction-of-a-symmetry]] with the guarded direction
being, as always, the one that already hurt.

The drift is the *status quo*, not something this change introduced, and one home
makes it a one-word fix instead of a re-plumb. But the fix is a WALL: growing the
`.zig` arm from identity to table-consulting will refuse programs that compile
today, on purpose. That is a language ruling and it has not been made.

## What would correct this belief

A third target close enough to Zig that it, too, can pass expressions through
unmodified — which would show that "the second target forces the definition" was
really "an unlike-enough target forces the definition," and that likeness rather
than count is the variable. The census makes that testable rather than
rhetorical: of 750 pure `.k` files only 62 use any Zig-only expression form, and
`orelse`, `catch`, `.?`, `try` and `|err|` appear zero times. The surface is
already far closer to Koru than to Zig, so a third host may find much less to
refuse than JavaScript did.

## The third target arrived (k-sharp, 2026-10-05): the variable is which LAYER the host can absorb, not likeness or count

The C# backend ran the experiment this belief's correction clause set up —
and the result is neither correction nor plain confirmation. C# did find less
to refuse in the expression vocabulary (ternary, arithmetic, comparisons all
lower cleanly), exactly as the census predicted. But it forced *new* namings
in organs JavaScript had never been strict enough to expose:

- **Handler arity.** A payloadless effect arm fired `tick()` worked in JS
  because JS absorbs call-shape mismatches; `Func<dynamic, dynamic>` in C#
  makes `tick()` a RuntimeBinderException. The arm's *fire signature* —
  payloadless `Func<dynamic>` vs payload-bearing `Func<dynamic, dynamic>` —
  had to become part of the contract, spelled by the emitter, invisible to
  every target that came before.
- **Presence as a value.** An omitted optional resuming arm was "absent" in
  JS because `undefined` is both a value and a callable-ish; C#'s `null`
  forces the distinction to be *spelled*: the member is emitted
  `(object)null` so a producer-side `ask != null` can read presence, while an
  omitted void arm gets a no-op delegate. Two different fill policies for two
  different arm kinds — a distinction the semantics always had and no host
  had ever made observable.
- **Literal position.** `[1,2,3]` passed through verbatim into JS and Zig
  because both hosts read `[` the same way in every position; C#'s collection
  expressions are legal only under a target type, so `foreach (var x in […])`
  is CS9176. The emitter now has to know `[` in *literal* position
  (`new dynamic[] {…}`) from `[` in index position — a positional
  distinction no previous host's grammar had ever demanded.
- **The skip list itself.** The Zig emitter carries a hardcoded
  `foreign_targets` registry — `{"gpu","js","python","wasm","glsl"}` — and
  `cs` wasn't in it, so `.kcs` facet bodies leaked into Zig emission until
  the list was amended. "Foreign" was never a computed property; it was an
  enumeration waiting to go stale, and only a *new* foreign body could show
  it. Every emitter addition re-opens every existing emitter's hardcoded
  notion of what it isn't.

The refined claim: each target names the surface **at the layer where its own
permissiveness runs out**. JS named the expression vocabulary because JS
refuses syntax it doesn't know; C# named dispatch semantics because C#
refuses arity and nullity it can't absorb — while staying permissive exactly
where JS was (expressions pass through fine). The number of targets is not
the variable, and likeness-to-Zig is not the variable: the variable is which
layer the *newest* host cannot pass through, and the surface is finished being
named only when no host can find a layer nobody enumerated.

## The fourth target (CompCert C, 2026-10-14): two more layers named — width-indexed operators and member-call spelling

The no-C census (201 store/grid tests, `--lang=c`, then ccomp +
byte-diff on the 16 emitters) found two leaks the first three targets
had all silently absorbed:

- **Width-indexed operator semantics.** `*%`/`+%`/`-%` passed verbatim
  into C — a syntax error at the oracle, the same class the JS lane
  fixed with `Math.imul` / `| 0`. But the C lane cannot copy the JS
  answer: JS can hardcode i32 because its int model *is* i32, while the
  C lane already erased declared int width (every cell is `long long`).
  Wrapping is defined at the operand's DECLARED width, so wrap-at-i64
  is not a lowering but a different program — `6000000000` where
  `1705032704` was pinned. The layer C named: *operator semantics that
  are indexed by a width the target's representation has discarded.*
  The correct verdict was a named refusal (`LowerDiag.unsupported_op`,
  KORU047), not a plausible shape. An emitter that can only produce the
  wrong answer must refuse — the syntax error it replaces was the good
  outcome.
- **Member-call spelling.** `store.qrewrite` minted
  `__koru_store_<S>.__koru_handle_of(d)` — valid on Zig, JS, and CS
  because all three let a value carry callables. C's struct members are
  data; the handle minter is a free function `__koru_handle_of_<S>(d)`.
  The layer: *method-call syntax is a host capability*, and every
  earlier host happened to have it.

The refined claim survives: each new host names the layer where its own
permissiveness runs out. C's layer is not expressivity — it is
*representation*: a target whose cell erases type detail forces
refusals that richer cells never reach. The surface is still not
finished being named.
