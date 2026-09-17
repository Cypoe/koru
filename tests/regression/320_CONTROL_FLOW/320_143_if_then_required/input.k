// PIN — `if`'s `then` arm is REQUIRED; only `else` is optional.
//
// The declaration is `~[keyword]pub tor if { expr: Expression } | then | ?else`
// (koru_std/control.kz). This test pins the call site that handles `else` and
// omits `then`: it must be REFUSED with the ordinary required-branch diagnostic
// (KORU022), located at the `if` head.
//
// WHY the asymmetry, since `| ?then` used to be accepted here: it compiled and
// ran, emitting `if (c) { } else { f(); }` — an `if` whose true arm is empty,
// indistinguishable from a call site that simply forgot the arm. `else` stays
// optional because `if(c) | then |> f()` (act only when c) is a complete
// statement; the same is not true of the missing `then`.
//
// The ruling is not a tidy-up, and it costs nothing: census over every Koru file
// in the tree (.k/.kz/.kc/.kjs) — 258 `if` call sites, 238 carrying both arms, 20
// then-only, ZERO else-only. Requiring `then` forbids a spelling nothing uses and
// routes the omission through the wall a required terminal already has (400_097),
// on both targets. Re-spelling the declaration with `| ?then` makes THIS test —
// not a silent empty arm in someone's program — the thing that goes red.
import std/io

if(42 > 10)
| else |> std/io:print.ln("else only")
