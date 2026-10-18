// CHALLENGE 800_010 — "deadbolt": a two-vault counting desk under a
// two-lock ordering protocol.
//
// Three lifecycles interleave every round:
//   *Vault  free! <-> held!    seized in canonical id order,
//                              released LIFO — never out of order,
//                              never left held.
//   *Guard  none -> one -> two the depth witness. It cannot stand
//                              down at <two!> and cannot pair at
//                              <none!> — LIFO is the only path the
//                              types admit.
//   *Attest open!              the notary, borrowed (never consumed)
//                              through every round, sealed at close.
//
// Custody moves by recursion: every tor CONSUMES the obligations
// (<!free>, <!none>) at its params and hands them to the next call —
// the loop-carry vehicle this language offers. The base arm owns
// teardown: closing balances read, both vaults and the guard retired
// inside the session. Every arm discharges: | short releases both
// vaults in LIFO order just like | moved does.
//
// Two frontiers stand adjacent (observed here, unpinned):
//   - record-field obligations die across any call boundary, so the
//     { g, lo, hi } bundle tors this protocol wants are unwriteable —
//     the |> chains here carry the same bindings instead;
//   - a producing if can only yield a record it constructs literally
//     (`.{ }` repack), so each decision level is its own tor — every
//     if below sits at a subflow's top level, never nested.

import std/io
import app/lib/vault
import app/lib/order

tor amt-for { i: i64 } -> i64
amt-for -> @mod(i * 53 + 17, 120)

tor session-end { moved: i64, shorts: i64, fa: i64, fb: i64 } -> { moved: i64, shorts: i64, fa: i64, fb: i64 }
session-end -> { moved, shorts, fa, fb }

// One ordered acquisition + transfer + LIFO release, dir a->b,
// canonical seize order a first.
tor ab-a { i: i64, n: i64, g: *app/lib/vault:Guard<!none>, va: *app/lib/vault:Vault<!free>, vb: *app/lib/vault:Vault<!free>, a: *app/lib/vault:Attest<open>, moved: i64, shorts: i64, amt: i64 } -> { moved: i64, shorts: i64, fa: i64, fb: i64 }
ab-a = app/lib/order:post(g): g1
    |> app/lib/order:seize(v: va): lo
    |> app/lib/order:seize(v: vb): hi
    |> app/lib/order:pair-up(g: g1): g2
    |> app/lib/vault:witness(a)
    |> app/lib/vault:shift(src: lo, dst: hi, amt)
        | moved m |> std/io:print.ln("  moved {{ m:d }}")
            |> app/lib/order:yield-inner(g: g2): g3
            |> app/lib/order:hand-back(v: hi): hf
            |> app/lib/order:stand-down(g: g3): g4
            |> app/lib/order:hand-back(v: lo): lf
            |> round(i: i + 1, n, g: g4, va: lf, vb: hf, a, moved: moved + 1, shorts): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }
        | short |> std/io:print.ln("  move {{ amt:d }} SHORT — insufficient")
            |> app/lib/order:yield-inner(g: g2): g3
            |> app/lib/order:hand-back(v: hi): hf
            |> app/lib/order:stand-down(g: g3): g4
            |> app/lib/order:hand-back(v: lo): lf
            |> round(i: i + 1, n, g: g4, va: lf, vb: hf, a, moved, shorts: shorts + 1): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }

// Same transfer, canonical order b first (b carries the lower id).
tor ab-b { i: i64, n: i64, g: *app/lib/vault:Guard<!none>, va: *app/lib/vault:Vault<!free>, vb: *app/lib/vault:Vault<!free>, a: *app/lib/vault:Attest<open>, moved: i64, shorts: i64, amt: i64 } -> { moved: i64, shorts: i64, fa: i64, fb: i64 }
ab-b = app/lib/order:post(g): g1
    |> app/lib/order:seize(v: vb): lo
    |> app/lib/order:seize(v: va): hi
    |> app/lib/order:pair-up(g: g1): g2
    |> app/lib/vault:witness(a)
    |> app/lib/vault:shift(src: hi, dst: lo, amt)
        | moved m |> std/io:print.ln("  moved {{ m:d }}")
            |> app/lib/order:yield-inner(g: g2): g3
            |> app/lib/order:hand-back(v: hi): hf
            |> app/lib/order:stand-down(g: g3): g4
            |> app/lib/order:hand-back(v: lo): lf
            |> round(i: i + 1, n, g: g4, va: hf, vb: lf, a, moved: moved + 1, shorts): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }
        | short |> std/io:print.ln("  move {{ amt:d }} SHORT — insufficient")
            |> app/lib/order:yield-inner(g: g2): g3
            |> app/lib/order:hand-back(v: hi): hf
            |> app/lib/order:stand-down(g: g3): g4
            |> app/lib/order:hand-back(v: lo): lf
            |> round(i: i + 1, n, g: g4, va: hf, vb: lf, a, moved, shorts: shorts + 1): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }

// Direction b->a, canonical seize order a first.
tor ba-a { i: i64, n: i64, g: *app/lib/vault:Guard<!none>, va: *app/lib/vault:Vault<!free>, vb: *app/lib/vault:Vault<!free>, a: *app/lib/vault:Attest<open>, moved: i64, shorts: i64, amt: i64 } -> { moved: i64, shorts: i64, fa: i64, fb: i64 }
ba-a = app/lib/order:post(g): g1
    |> app/lib/order:seize(v: va): lo
    |> app/lib/order:seize(v: vb): hi
    |> app/lib/order:pair-up(g: g1): g2
    |> app/lib/vault:witness(a)
    |> app/lib/vault:shift(src: hi, dst: lo, amt)
        | moved m |> std/io:print.ln("  moved {{ m:d }}")
            |> app/lib/order:yield-inner(g: g2): g3
            |> app/lib/order:hand-back(v: hi): hf
            |> app/lib/order:stand-down(g: g3): g4
            |> app/lib/order:hand-back(v: lo): lf
            |> round(i: i + 1, n, g: g4, va: lf, vb: hf, a, moved: moved + 1, shorts): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }
        | short |> std/io:print.ln("  move {{ amt:d }} SHORT — insufficient")
            |> app/lib/order:yield-inner(g: g2): g3
            |> app/lib/order:hand-back(v: hi): hf
            |> app/lib/order:stand-down(g: g3): g4
            |> app/lib/order:hand-back(v: lo): lf
            |> round(i: i + 1, n, g: g4, va: lf, vb: hf, a, moved, shorts: shorts + 1): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }

// Direction b->a, canonical seize order b first.
tor ba-b { i: i64, n: i64, g: *app/lib/vault:Guard<!none>, va: *app/lib/vault:Vault<!free>, vb: *app/lib/vault:Vault<!free>, a: *app/lib/vault:Attest<open>, moved: i64, shorts: i64, amt: i64 } -> { moved: i64, shorts: i64, fa: i64, fb: i64 }
ba-b = app/lib/order:post(g): g1
    |> app/lib/order:seize(v: vb): lo
    |> app/lib/order:seize(v: va): hi
    |> app/lib/order:pair-up(g: g1): g2
    |> app/lib/vault:witness(a)
    |> app/lib/vault:shift(src: lo, dst: hi, amt)
        | moved m |> std/io:print.ln("  moved {{ m:d }}")
            |> app/lib/order:yield-inner(g: g2): g3
            |> app/lib/order:hand-back(v: hi): hf
            |> app/lib/order:stand-down(g: g3): g4
            |> app/lib/order:hand-back(v: lo): lf
            |> round(i: i + 1, n, g: g4, va: hf, vb: lf, a, moved: moved + 1, shorts): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }
        | short |> std/io:print.ln("  move {{ amt:d }} SHORT — insufficient")
            |> app/lib/order:yield-inner(g: g2): g3
            |> app/lib/order:hand-back(v: hi): hf
            |> app/lib/order:stand-down(g: g3): g4
            |> app/lib/order:hand-back(v: lo): lf
            |> round(i: i + 1, n, g: g4, va: hf, vb: lf, a, moved, shorts: shorts + 1): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }

// The order decision for direction a->b: peek both ids, seize the
// lower first.
tor dir-ab { i: i64, n: i64, g: *app/lib/vault:Guard<!none>, va: *app/lib/vault:Vault<!free>, vb: *app/lib/vault:Vault<!free>, a: *app/lib/vault:Attest<open>, moved: i64, shorts: i64 } -> { moved: i64, shorts: i64, fa: i64, fb: i64 }
dir-ab = amt-for(i): amt
    |> app/lib/vault:id-of(v: va): ida
    |> app/lib/vault:id-of(v: vb): idb
    |> std/io:print.ln("round {{ i:d }}: move {{ amt:d }} vault {{ ida:d }} -> vault {{ idb:d }}")
    |> if(ida < idb)
        | then |> std/io:print.ln("  seize {{ ida:d }} then {{ idb:d }}")
            |> ab-a(i, n, g, va, vb, a, moved, shorts, amt): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }
        | else |> std/io:print.ln("  seize {{ idb:d }} then {{ ida:d }}")
            |> ab-b(i, n, g, va, vb, a, moved, shorts, amt): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }

// The order decision for direction b->a.
tor dir-ba { i: i64, n: i64, g: *app/lib/vault:Guard<!none>, va: *app/lib/vault:Vault<!free>, vb: *app/lib/vault:Vault<!free>, a: *app/lib/vault:Attest<open>, moved: i64, shorts: i64 } -> { moved: i64, shorts: i64, fa: i64, fb: i64 }
dir-ba = amt-for(i): amt
    |> app/lib/vault:id-of(v: va): ida
    |> app/lib/vault:id-of(v: vb): idb
    |> std/io:print.ln("round {{ i:d }}: move {{ amt:d }} vault {{ idb:d }} -> vault {{ ida:d }}")
    |> if(ida < idb)
        | then |> std/io:print.ln("  seize {{ ida:d }} then {{ idb:d }}")
            |> ba-a(i, n, g, va, vb, a, moved, shorts, amt): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }
        | else |> std/io:print.ln("  seize {{ idb:d }} then {{ ida:d }}")
            |> ba-b(i, n, g, va, vb, a, moved, shorts, amt): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }

// Direction alternates by parity.
tor dispatch { i: i64, n: i64, g: *app/lib/vault:Guard<!none>, va: *app/lib/vault:Vault<!free>, vb: *app/lib/vault:Vault<!free>, a: *app/lib/vault:Attest<open>, moved: i64, shorts: i64 } -> { moved: i64, shorts: i64, fa: i64, fb: i64 }
dispatch = if(@mod(i, 2) == 0)
    | then |> dir-ab(i, n, g, va, vb, a, moved, shorts): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }
    | else |> dir-ba(i, n, g, va, vb, a, moved, shorts): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }

// The desk's session: recurse the rounds; at the base the desk
// itself retires the vaults and the guard — the session owns the
// whole lifecycle.
tor round { i: i64, n: i64, g: *app/lib/vault:Guard<!none>, va: *app/lib/vault:Vault<!free>, vb: *app/lib/vault:Vault<!free>, a: *app/lib/vault:Attest<open>, moved: i64, shorts: i64 } -> { moved: i64, shorts: i64, fa: i64, fb: i64 }
round = if(i == n)
    | then |> app/lib/vault:peek-bal(v: va): fa
        |> app/lib/vault:peek-bal(v: vb): fb
        |> app/lib/vault:retire-vault(v: va)
        |> app/lib/vault:retire-vault(v: vb)
        |> app/lib/vault:retire-guard(g)
        |> session-end(moved, shorts, fa, fb): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }
    | else |> dispatch(i, n, g, va, vb, a, moved, shorts): rec -> { rec.moved, rec.shorts, rec.fa, rec.fb }

// ── the run ──────────────────────────────────────────────────────
// vault b carries the LOWER id (1) — every round's canonical seize
// order is vault 1 first, whichever direction money moves.

app/lib/vault:mint-vault(id: 2, bal: 300): va
|> app/lib/vault:mint-vault(id: 1, bal: 80): vb
|> app/lib/vault:mint-guard(): g
|> app/lib/vault:mint-attest(): att
|> std/io:print.ln("desk open: vault 2 bal 300, vault 1 bal 80")
|> round(i: 0, n: 8, g, va, vb, a: att, moved: 0, shorts: 0): res
|> app/lib/vault:seal-attest(a: att): attested
|> std/io:print.ln("desk closed: vault 2 bal {{ res.fa:d }}, vault 1 bal {{ res.fb:d }}")
|> std/io:print.ln("moved {{ res.moved:d }}, short {{ res.shorts:d }}, attested {{ attested:d }}")
