# 015_fleet_mail

The routed turn, priced — the koru spelling of celld's remote call. A
refused caller (`| held-by`) posts the turn to the cell's mailbox; the
owner of record drains it as a real turn (interpreter dispatch + durable
commit). Measured as two arms:

| arm | what it isolates |
|---|---|
| `send` | the refused caller's post — `makePath(inbox)` + tmp write + rename per turn |
| `deliver` | the owner's drain — per mail: file read + `run(source)` + capture commit + delete |
| `baseline.zig` | the same file lifecycle with no interpreter and no turn execution — the mail-protocol floor |

The end-to-end routed-turn price is `send + deliver`: the refused side and
the owner side are timed separately because in production they are
different processes — a single round-trip number would average two
machines' clocks.

Mins over 3 runs (2026-10-21, calm box): send ~97µs/post vs baseline ~87µs;
deliver ~185µs/mail vs a ~48µs drain-file floor — the remainder is the
durable turn already priced in 013 (~121µs) plus ~16µs of mail
parse/dispatch. Routed turn end-to-end ≈ 280µs, vs celld's ~4.6ms HTTP
request path — with the named asymmetries: no wire, buffered-not-fsync'd
commit, one shared filesystem instead of a bucket.

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
