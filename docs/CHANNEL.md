# std/channel — channels as a first-class construct

**Tree pinned:** `bd31d8f2d` on `main`, measured 2026-09-21; corrected
2026-09-24 (surface spelling under redesign — see below).
**Status:** design proposal. The mechanism analysis below is measured
against the tree. The **surface spelling is not ruled** — an earlier
version of this doc shipped `std/channel(inbox: Reading, 256)`, which is
invented syntax: positional tails on `std/` heads are illegal (calls pun;
only the first `expr: Expression` slot is positional), and
`name: Proto` in arg position is a named arg, not a declaration pair.
The implementable surface awaits a legal declaration shape — do not write
code from this doc's spelling sections until that ruling lands.

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
| Vyukov bounded MPMC ring | `koru_std/rings.kz` — `MpmcRing(T, cap)`, `enqueue \| ok \| full`, `dequeue \| some v \| none` | the buffered data plane; CAS fast path, `full`/`none` as branches |
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

## The surface (UNDER RULING — spelling not legal yet)

What is settled in conversation with Lars:

- **The element type is a proto name.** `std/proto` is the nominal-type
  registry; `std/store` and `std/list:new` already drink from it. Channels
  of `Reading` vs `Score` never interchange — nominal, compile-time.
- **The consumer arm derives its name from the proto** — a channel of
  `Reading` fires `! reading`. The proto is the channel's vocabulary, the
  way a store's fields are its arms. `! closed` is channel state, not a
  message, and stays a fixed word.
- **`!` arms are competing consumers** — one value, one arm. Broadcast is
  a separate arm kind, deliberately not silently included.
- **Chain steps are `std/channel:send/recv/close`-family** — the
  `std/x:verb(subject, name: arg)` shape that `std/store:insert` already
  uses — with status arms `| ok | full | closed` and
  `| some | none | closed`.
- **Capacity is a named arg** (`capacity:` — the store convention), never
  a positional tail.

What is NOT settled — the questions that block a compilable surface:

- The declaration head's legal shape. `std/store:new(name, capacity: N) { fields }`
  is the existing pattern: bare name in the expr slot, `capacity:` named,
  vocabulary declared in a `{ }` body. Whether a channel declares its
  element as a body field (`{ reading: Reading }` — which would make
  `! reading` a *field* name, consistent with store arms) or takes the
  proto some other legal way is Lars's call.
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
