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

## What would correct this belief

A counterexample where the strict host's shape over-constrains the port —
some property the lax host's shape gets right *because* it stayed dynamic,
which the strict spelling can't express. Dynamic handler construction (a
handler set chosen at runtime rather than lexically at the call site) would
be such a case: the grammar does not currently allow it, but if it ever does,
the `where H : struct` model needs a fallback and the JS shape turns out to
have been load-bearing after all.
