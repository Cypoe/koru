# std/channel — channels as a first-class construct

**Tree pinned:** `bd31d8f2d` on `main`, measured 2026-09-21; corrected
2026-09-24 (surface ruled — see below).
**Status:** ruled surface, partial implementation. The mechanism analysis
below is measured against the tree. The surface was ruled 2026-09-24: the
declaration body is the proto-definition grammar (`{ name: Proto }`
entries), ruled for rings and channels alike. `std/rings` is implemented
and pinned (`320_090` migrated to pure Koru; `320_101`–`320_109` cover
proto elements, `full`/`none` arms, and the refusals). `std/channel`
(`koru_std/channel.kz`) is implemented against the same ruling and
green: all 18 `699_CHANNEL` pins pass (`run_regression.sh 699_*`,
2026-09-25) — buffered roundtrip, `full`/`none` arms, send-after-close,
close+drain, program-wide `!`-arm joins, competing consumers, multi-kind
channels, pump participation (`step`/`live`/`wait`), and the refusal set.

---

## The claim

Go channels are one construct — `chan T` — with two engines (rendezvous at
cap 0, ring buffer at cap n) and three verbs (send, recv, close) plus `select`.

Koru can express the same construct as a **composition of four mechanisms that
already exist**, and the composition lands differently in two places that
matter:

- **"Block" is never the primitive.** Go parks a goroutine; Koru spells
  backpressure and emptiness as *arms* (`| full`, `| none`), parks real
  threads with a futex when threads are in play, and parks *passes* — not
  threads — under `std/pump`.
- **Consumers are declared, not ambient.** `tap` is the echo of this: dynamic,
  bolted on, invisible to the construct. The `!`-arm join site makes the
  consumer set statically enumerable at compile time — fan-out becomes static
  dispatch into generated units (`emitVerbUnit`, `koru_std/pump.kz:299`).

## The substrate (measured this session)

| Mechanism | Where | What it gives the channel |
|---|---|---|
| Vyukov bounded MPMC ring | `koru_std/rings.kz` + `rings.new.kz`/`rings.ops.kz` — `std/rings:new(name, capacity: N) { value: Type }` decl, name-addressed `enqueue`/`dequeue` steps over the `MpmcRing(T, cap)` substrate | the buffered data plane; CAS fast path, `full`/`none` as branches, **now a real Koru surface** (320_090 + 320_101–109) |
| Effect branches | `! ask i64 -> i64`, handler `! ask v -> expr` — `400_132`, `670_060` | the tor calls the consumer's code; the resume is the consumer's answer — the rendezvous *shape* |
| Thread spawn ladder | `koru_std/threading.kz` — `worker.spawn` `.async`/`.await`/`.join` | the cross-thread plane |
| Compile-time pump | `koru_std/pump.kz` — `create`/`default`/`run`; verbs `step()->i32`, `live()->i64`, `wait(i)->{fd,wait_ns}` | the scheduler: pass loop + **one union `poll()` per all-idle pass** |
| `default`-tor join site | `store.default.kz` (`std/store(name) ! field` → watch), `pump.kz` `default` (`std/pump(name) ! step`) | the grammar this surface reuses |

Two measured facts about `pump`'s `run` worth the design's weight
(`pump.kz:740-801`): progress is counted per pass (`Σ step()`), and an
all-idle pass composes a *single* `poll()` over every participant's `wait`
interests — `fd = -1` is deadline-only, `wait_ns` caps the wait. A participant
with thread-arriving work can hand the pump an **eventfd** and cross-thread
wakes land in the same union poll. That closes the threads↔pump bridge.

## The execution model (corrected 2026-09-24)

An earlier version of this doc named a "deferred resume frontier" — a
missing mechanism where a flow suspends mid-expression and resumes later.
That framing was wrong, and it's worth saying precisely why:

- **There is no "mid-flow" to suspend.** A `|>` chain is not a call stack
  you stand inside; each step is a firing whose continuation is already
  structure. "Deferred" is not a property a call can have — it is a
  property of *who steps the unit*.
- **The arrow is inverted from mainstream languages.** The tor calls the
  consuming code — an effect fire invokes the handler bound at the call
  site (`__H.ask(q)` in emitted code; the handler set is comptime-known
  per site). The consumer never holds a handle on the producer; the
  producer holds the consumer's code. A `Resume`-style capability object
  is an import from languages that pass computations around as values —
  Koru doesn't.
- **Effect branches can already respond deferred.** The branch is
  uncolored; the caller takes the color by which surface it invokes and
  how the composition is arranged. Handlers can return continuations.
  A "blocking" channel is therefore a composition question, not a
  mechanism gap.

Consequence for channels: nothing about a channel needs the language to
gain a suspend/resume primitive. A `!`-arm consumer is already deferred
execution — the channel calls the consumer's code when a value lands.
Rendezvous (cap 0) is a *surface* question — a send whose ok-continuation
fires on the consumer's take — not a compiler gap.

## The surface (ruled 2026-09-24 — implemented for rings, pending for channel)

The ruled shape: **a `{ }` body on a `std/` decl declares a typed
vocabulary — the proto-definition grammar — and the construct decides the
algebra.** `name: Type` entries, parsed by `struct_literal.parseFields`
(the same parser `std/store:new` uses); each entry resolves to a declared
proto or a scalar.

```koru
std/channel:new(inbox, capacity: 256) { reading: Reading, alert: Alert }

std/rings:new(feed, capacity: 256) { value: u64 }
```

- **Arm names are declared, not derived.** `{ frame: Packet }` fires
  `! frame`; `reading: Reading` fires `! reading` — the same-initial
  coincidence is the common case, not a rule. The proto is the payload,
  the word is the arm — exactly `! hp` under `std/store(game)`.
- **Multi-kind is the field list.** Each entry is one kind: one lane,
  one arm word, one payload proto.
- **`closed` is reserved** — channel lifecycle state, not a kind; a body
  entry named `closed` refuses.
- **A ring is the degenerate case** — one entry, one lane, no arms:
  `std/rings:new(feed, capacity: N) { value: u64 }`. The name still does
  work: it labels the element in diagnostics and generated units.
- **Entries are comma-separated** — `struct_literal` discipline; a
  newline-separated second entry gets the missing-comma refusal.
- **Scalars collapse the same way protos do** — `{ value: u64 }` is a
  legal element; a proto is a struct; a scalar is the degenerate word.
- **No `*`, arrays, or phantom-typed elements** — a slot holds plain
  values by copy; borrows and `<live!>` elements refuse with teaching.
- **`!` arms are competing consumers** — one value, one arm. Broadcast is
  a separate arm kind, deliberately not silently included.
- **Chain steps are `std/channel:send/recv/close`-family** — with status
  arms `| ok | full | closed` and `| some | none | closed`. Values ride
  `v:`-labeled args (the `std/list` convention — a second bare positional
  names no parameter and the pun law refuses it before transforms run:
  `send(inbox, v: r)`, `enqueue(feed, v: 42)`).
- **Capacity is a named arg** (`capacity:` — the store convention), never
  a positional tail.

What is NOT settled:

- Broadcast spelling (`! each` or otherwise) — deferred.
- Per-flow select (one flow waiting on two channels) — a spelling
  question, not a mechanism gap.

## The three "block" tiers

| Tier | Mechanism | Go analog | Status |
|---|---|---|---|
| Non-blocking arms | `full`/`none`/`closed` branches | `select` + `default` | **grounded today** |
| Cross-thread park | `std.Thread.Futex` wait/wake in the `~proc|zig` impls | `gopark`/`goready` | grounded mechanism, unbuilt surface |
| Same-thread pump | `step` returns 0 → `wait` → re-step; continuation is the pass | — (Go has no analog) | grounded machinery, unbuilt surface |

The futex tier is the honest Go-parity engine: Go's channel is a mutex + wait
queues internally, so a Vyukov CAS fast path in front of a futex park is the
*same* contention story with a lock-free head — the shootout is real.

## Done-gates

1. `tests/regression/600_STDLIB/699_CHANNEL/` — MUST_RUN pins once the
   surface is ruled: buffered roundtrip; `full`/`none`/`closed` arms each
   hit; send-after-close refusal; close-then-drain; two consumers
   competing; a pump-joined two-channel program; futex-parked recv across
   `worker.spawn` threads.
2. `koru-benchmarks/suites/channels/` — the showoff artifact: prime-sieve
   pipeline (Go's own channel showcase — one goroutine per prime) against a
   Koru version with one pump participant per prime. Go reference +
   `expected.txt` oracle + `bench.sh` column, same board format as
   `osprey-compute-kernels`. The comparison writes itself: N goroutines vs N
   participants on one thread.
3. On ruling: seal as `challenges/024_*.md`, `kind: commission` — convergent
   work, one right answer, appears under open commissions.

## Lessons the first implementation surfaced (2026-09-24)

- `std/channel(name: Proto, cap)` shipped in `koru_std/channel.kz` +
  `699_CHANNEL` pins and **compiled** — because positional tails on `std/`
  heads were never refused anywhere. `std/store:new(game, 37)` drops the
  `37` silently; `std/pump:create(main, 5)` drops the `5`. Ordinary tor
  calls did enforce the law (`PARSE006: bare argument … does not name a
  parameter`). Fixed 2026-09-24: `checkBareArgPunning` (`src/main.zig`)
  narrowed the machinery-callee exemption to name-matching only — arg[0]
  stays the positional subject, later bare args must be punnable
  identifier paths or explicit labels. Pins `210_240`–`210_242` now green;
  `210_243` is the tor-call control. The invented channel surface was
  removed; the surface awaits a legal spelling.
- `had_explicit_label` was silently dropped by `flow_parser.zig`'s
  `convertArgPairs` on the interpreter path (fixed in the same change);
  `ast_json.zig` round-trips it correctly — the field that distinguishes
  labeled from positional args now reaches every consumer.
