# 015_fleet_mail

The routed turn, priced — the koru spelling of celld's remote call. A
refused caller (`| held-by`) posts the turn to the cell's mailbox; the
owner of record drains it as a real turn (interpreter dispatch + durable
commit). Measured as three arms:

| arm | what it isolates |
|---|---|
| `send` | the refused caller's post — `makePath(inbox)` + tmp write + rename per turn |
| `deliver` | the owner's drain — per mail: file read + `run(source)` + capture commit + delete |
| `pipelined` | the resident tier — 8 host producer threads claim-post TURNS `Mail` records into a capacity-16 `std/channel` ring; the pump's `! turn` consumer mints `Mail<posted!>` per mail and a drain must settle it (KORU030 makes dropped mail a compile error); `settle` runs the same `run(source)` + capture commit as the file drain |
| `baseline.zig` | the same file lifecycle with no interpreter and no turn execution — the mail-protocol floor |

The end-to-end routed-turn price is `send + deliver`: the refused side and
the owner side are timed separately because in production they are
different processes — a single round-trip number would average two
machines' clocks.

The `pipelined` arm is the celld "8 connections" counterpart: producers on
threads saturate a bounded ring while the owner serializes turns — the
same per-owner serial drain celld's DO enforces, without the HTTP front.
One warmup mail goes through the real `post → send | ok` custody path;
that custodial send is what seeds the `! turn` mint (the channel learns a
kind's transit state from observed sends), and it counts in the totals:
61 turns commit in the timed window. Foreign producers bypass the ledger —
custody is a compile-time boundary, and a raw enqueue carries bytes, same
as an HTTP client carrying no debt.

Mins over 3 runs (2026-10-21, calm box): send ~97µs/post vs baseline ~87µs;
deliver ~185µs/mail vs a ~48µs drain-file floor — the remainder is the
durable turn already priced in 013 (~121µs) plus ~16µs of mail
parse/dispatch. Routed turn end-to-end ≈ 280µs, vs celld's ~4.6ms HTTP
request path — with the named asymmetries: no wire, buffered-not-fsync'd
commit, one shared filesystem instead of a bucket.

Pipelined mins over 3 runs (2026-10-23, calm box): ~12.9ms for 61 turns ≈
211µs/turn ≈ ~4,700 turns/s sustained — vs celld's ~789 rps pipelined at 8
connections. Two named asymmetries: the ring is 16-deep so producers spin
on real backpressure (celld's HTTP accepts are kernel-buffered), and every
turn still pays the durable `state.kv` commit — the number is transport +
durable turn, not transport alone. The residual ~28µs/turn over the file
deliver arm is pump pass overhead plus genuine producer contention on the
bounded ring.

Delivery is at-least-once: a mail file is deleted only after its `! mail`
arm returns, so a crash mid-turn redelivers on the next drain. The gate
counts *committed* turns, so redelivery shows up as hits > TURNS.

## Correctness gate

`grain` must show `hits == TURNS` — every routed turn committed exactly
once — and drain must report `delivered == TURNS`. A mailbox that dropped
or duplicated a turn shows up as a wrong checksum, not a fast number.

## Run

```sh
./run.sh
```
