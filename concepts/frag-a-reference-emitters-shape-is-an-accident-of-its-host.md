---
type: belief
id: frag-a-reference-emitters-shape-is-an-accident-of-its-host
provenance: k-sharp effect dispatch, 2026-10-05 — porting js_emitter's
  runtime-object handlers onto C# produced the worst of both hosts before
  Lars asked whether effect branches are "inlined on the other platforms"
ts: 2026-10-05
---

# A reference emitter's shape is an accident of its host; port the semantics, not the shape (belief)

When the C# backend needed effect dispatch, the natural move was to port the
js_emitter's design — it is the most recently written emitter, it is readable,
and its dispatch model is well-factored: a `Handlers_<id>` object literal whose
members are closures, a `__koru_handlers` parameter, one member per arm, fires
as property-call. Transplanting that shape onto C# produced anonymous objects
of `Func<dynamic>` — and it was wrong in both directions at once: the emitted
code paid the DLR's dynamic member-binding cost on every arm access *and* got
none of the monomorphization a statically-typed host offers. The port was
faithful and the result was bad, which is the signature of porting the wrong
thing.

The mistake was treating js_emitter's *shape* as the semantics. The actual
contract of effect dispatch — a per-call-site, lexically closed set of handler
bodies, resolvable statically — is written most explicitly in the Zig emitter,
because Zig is the strictest host about exactly that property: `comptime
__H: type` *is* per-site static resolution spelled in the language. JavaScript
is lax about it — an object of closures is the same runtime shape as every
other JS dispatch, so nothing in the js_emitter had to *name* staticness; the
property is invisible in the permissive host's shape and load-bearing in the
strict host's.

**The general claim:** pick the reference implementation whose host is
strictest about the property the port needs, not the reference that is most
convenient. The lax host's shape will always look simpler — that is what lax
means — and porting it imports its accidents along with its structure. The
strict host's shape *is* the property made visible: `comptime __H: type`
maps directly onto C#'s `where H : struct, IOps` (generic-struct ops +
property members + shared no-op fills, the same per-site monomorphization
LLVM gets through Zig's type parameter and the JIT gets through value-type
instantiation), while `Func<dynamic>` is the JS answer wearing a C# costume.

This is the port-side dual of
[[frag-a-second-target-is-what-forces-a-language-to-name-its-own-vocabulary]]:
that belief says the *language's* surface gets named where a host can't pass
through; this one says an *emitter's* shape is already named by its host's
pass-through profile — so the permissive host's emitter is the wrong spec to
copy from.

**Second instance, 2026-10-14 — the envelope, and this time the benchmark
named it before the host did.** The same mistake had survived in the
*input/output envelope*: `dynamic __koru_input`, anonymous `new { tag, done
}` produces, `dynamic` handler returns — the JS object literal transplanted
again, one layer down. What surfaced it was not a strict host refusing but a
measurement: 008_effect_dispatch decomposed a 13.3ns/call effect dispatch
into ~2.2ns of dispatch and ~11ns of anonymous-object churn (56B/call),
and zig's emitted `Input`/`Output` struct+union pair was sitting in the
same tree as the strict spelling the whole time. Porting it — `struct
Input` with declared field types and initializer defaults, `struct Output`
with `tag` + one payload member per terminal branch, `handler<H>(Input, H)
→ Output` — lands the *generated* code at 2.2ns and 0 B/call, identical to
the handwritten typed-io control. The honest bound the lax host had been
hiding: the envelope can only be typed where the emitter authors both
sides — an opaque `|cs` body writes its own `new { tag, done }`, so its
boundary stays `dynamic` by contract, not by accident.

**Third instance, 2026-10 — captures, and the strict host named a
semantic the lax host never had to.** The last `Func` on the dispatch
surface was the arm bodies themselves — a delegate is the only C#
closure, so arms looked stuck behind the ~1.9ns delegate-invoke floor.
Zig's nested `Handlers_N` fns const-capture enclosing bindings natively:
the strict host's shape made visible that Koru arm bodies read enclosing
locals as *snapshots* — legal semantics with a precise contract. A struct
method cannot close over a local, but a struct *field* spells the same
snapshot: the emitter scans each arm body for references to enclosing
flow locals and materializes them as `__cap_*` fields — const-capture
ported, not closure capture imitated. The measured landing: the
generated arm, as a `void tick()` method on the ops struct, inlines
through the monomorphized `handler<H>` into the loop — 0.3ns/call,
measuring identical to the `direct` static-call atom and to the
handwritten `struct-method` comparator. The lax host's closure would
have left the claim at "2.2ns is the floor"; the strict host's shape
named what the semantic actually is, and the floor turned out to be
zero.

**And the second instance's bound was wrong — the envelope typed
anyway.** That paragraph ended with "the envelope can only be typed
where the emitter authors both sides" — opaque `|cs` text authors its
own result, so `beat` stayed `dynamic` at ~11ns "by contract, not by
accident." The bound was assumed, not enforced: the event *decl* knows
every branch type, so `struct Output` is public and statically nameable
by host text. Making it the contract — `handler` returns `Output` for
every branch tor regardless of impl kind, host-authored `return new
Output { tag = "done", … }`, the C# compiler refusing the old anonymous
shape — moved the opaque arm from 10.8ns to 0.3ns, identical to
`direct`. The generalization worth keeping: when the lax-host shape
leaks into a port as an untyped boundary, the fix is not always
"the emitter can't type what it didn't write" — sometimes it is "write
the type anyway and let the host's checker enforce it on whoever
did write." The measured residue of `dynamic` on that path is what a
consumer pays for insisting on it: 10.0ns + 56B/call to read the same
typed `Output` through a dynamic reference.

**Fourth instance, 2026-10 — the lax spelling inside authored host text,
and the strict host's refusal moved to runtime.** The tranche facets
declared module state the JS way: `public static dynamic counter = 0` —
the `.kjs` facet's `let counter = 0` ported, because `dynamic` is the
closest C# spelling of an untyped binding. It *compiles* — that is the
accident — and then `counter + v` dies in the DLR binder: the boxed `int`
meets a `ulong` arm parameter and `int + ulong` has no operator in C#
either, so the error the strict host would have refused at compile time
detonates at runtime instead (`RuntimeBinderException`, a cs-runtime red
four layers down the stack). Typing the state at the tor's declared type
(`ulong counter`) turns the same source green. The wrinkle worth keeping:
`dynamic` does not merely cost speed here — it *moves the boundary the
checker can see*. Every `dynamic` in host text is a hole in the strict
host's coverage, and the failures it hides land one stage later, in the
binder, where they read like emitter bugs but are authoring bugs. The
facet-authoring rule follows: host text types its state at the declared
tor types; `dynamic` is for boundaries the decl cannot name, not for
laziness about ones it can.

## What would correct this belief

A counterexample where the strict host's shape over-constrains the port —
some property the lax host's shape gets right *because* it stayed dynamic,
which the strict spelling can't express. Dynamic handler construction (a
handler set chosen at runtime rather than lexically at the call site) would
be such a case: the grammar does not currently allow it, but if it ever does,
the `where H : struct` model needs a fallback and the JS shape turns out to
have been load-bearing after all.

2026-10-05 — the shape's *names* are accidents too, not only its
dispatch model. The tagged-union rendering every emitter shares —
`tag` discriminates, each branch's payload sits in a member named for
the branch — collided the moment a store column was literally named
`tag` (690_336): the generated C# `Output` declared `public string
tag` and `public long tag` in the same struct. Zig never noticed
because a field named `tag` on a tagged union is just a payload
member; C#'s flattened record made the reservation visible. The fix
kept `tag` as the discriminator — authored `.kcs` bodies spell
`new Output { tag = "…" }` and that convention is load-bearing —
and renamed only the colliding payload member (`__ktag`), mapped
identically at decl, ctor, and read sites. The generalization: a
host shape's reserved vocabulary is part of the accident — port the
semantics and the shape's *namespace discipline* must survive contact
with the user's own field names.

2026-10-05 — the accident can also be a spelling a third host has
never been asked to compile. The `[tree]` store's cycle-guard proc
(`__store_writec_*`) emitted `const` locals — legal Zig, illegal C#,
which wants `var` for non-constant initializers — and built its
forwarded call through `HS.argRec`, which spells an anonymous
`new { … }` that cannot convert to the callee's typed `Input` struct.
Zig and JS compiled it for months because a `.{}`/`{…}` literal IS the
argument convention on those hosts; C# simply never saw the path —
no `695_STORE_TREE` test carried a `cs` mark, so the emission sat
green-by-absence until a probe compiled it and `dotnet` refused.
The fix is the same discipline twice: per-host spelling where the
host's grammar differs (`var`/`const`), and `HS.callArg` — the typed
`new <ev>_event.Input { … }` — wherever the callee's `Input` is
declared rather than wildcard. The generalization: a per-host
emission arm that no test marks is not ported, it is merely unstruck;
the sweep's board is the set of marks, and the cold paths outside
it are where the next host's refusals live.

2026-10-05 — the host's *type inference* is an accident too. The
user-level `for|cs` emitted `for (var __koru_item = 0; …)` — `var`
binds the literal's width, so a counter over a `usize` range came
out `int` against a `long` bound: two `sxtw` per element, the only
difference between the emitted numeric loop and the handwritten
atom. C# compiled it happily — widening is legal, just not free —
and every test stayed green; only `DOTNET_JitDisasm` could see the
instructions the stopwatch couldn't separate from noise. The fix is
what the store sweeps already spelled: emit the declared type
(`long`), not `var`, where the source's type is known. The
generalization: type inference in generated code is an emission bug
class — `var` inherits the initializer's width, and the initializer
is a literal, not the semantics.
