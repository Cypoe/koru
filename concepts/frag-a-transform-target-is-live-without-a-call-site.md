---
type: belief
id: frag-a-transform-target-is-live-without-a-call-site
provenance: 2026-09-11 std surface census — 136 of 298 pub tors showed zero
  std/pkg:tor call sites, and the headline was about to print before the
  list `-i64` family was caught: `std/list:new(i64)` rewrites to `new-i64`
  through routeOpCall segments, so every "dead" -i64 tor is live
ts: 2026-09-11
---

# A transform target is live without a call site (belief)

Liveness of a `std` tor is a two-layer question. The visible layer is
call-site reachability — `std/pkg:tor` spelled in consumer source. The
invisible layer is transform-emission: a `~[comptime|transform]` tor
rewrites the user's call into a *different* tor (`routeOpCall`,
`"{verb}-{s}"` segment names, `synthesizeContainer`), and the target's
name never appears in any caller's source.

So "zero call sites" overcounts dead and hides the real architecture at
once: the `-i64` list family, `field:new-heap`, `fmt:*.impl`,
`io:print.blk.impl`, `store:default` all read dead to grep and are live
through rewrites. Before writing `dead` in any census, grep the
*transform bodies* for the routed name — the emitted call is the call
site.

The inverse belief (`frag-a-surface-with-no-callers-is-where-a-lie-survives`:
no callers ⇒ suspect) stays right about motivation — net.kz's fabricated
sockets survived because nothing called them — but it is silent about
*measurement*. This is the missing half: an un-called tor is a suspect,
not a corpse, until the rewrite layer has been searched.

Open question: the emitted-name routing table is implicit (scattered
`"{verb}-{s}"` format calls inside transform zig bodies). A declared
routing surface — one place that says which tors a transform can emit —
would make liveness decidable; nobody has built it.
