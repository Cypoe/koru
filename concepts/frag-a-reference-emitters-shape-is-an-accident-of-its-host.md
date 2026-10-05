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

## What would correct this belief

A counterexample where the strict host's shape over-constrains the port —
some property the lax host's shape gets right *because* it stayed dynamic,
which the strict spelling can't express. Dynamic handler construction (a
handler set chosen at runtime rather than lexically at the call site) would
be such a case: the grammar does not currently allow it, but if it ever does,
the `where H : struct` model needs a fallback and the JS shape turns out to
have been load-bearing after all.
