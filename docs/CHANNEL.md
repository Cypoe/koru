# std/channel — channels as a first-class construct

**Tree pinned:** `bd31d8f2d` on `main`, measured 2026-09-21.
**Status:** design proposal, pre-ruling. Every surface spelling below is a
proposal for the taste-gate — nothing here asserts syntax. Semantics are
argued from the current tree; each claim names the file or test that grounds
it, or is marked **unmeasured**.

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
| Effect branches | `! ask i64 -> i64`, handler `! ask v -> expr` — `400_132`, `670_060` | synchronous suspend/resume, dynamically scoped — the rendezvous *shape* |
| Thread spawn ladder | `koru_std/threading.kz` — `worker.spawn` `.async`/`.await`/`.join` | the cross-thread plane |
| Compile-time pump | `koru_std/pump.kz` — `create`/`default`/`run`; verbs `step()->i32`, `live()->i64`, `wait(i)->{fd,wait_ns}` | the scheduler: pass loop + **one union `poll()` per all-idle pass** |
| `default`-tor join site | `store.default.kz` (`std/store(name) ! field` → watch), `pump.kz` `default` (`std/pump(name) ! step`) | the grammar this surface reuses |

Two measured facts about `pump`'s `run` worth the design's weight
(`pump.kz:740-801`): progress is counted per pass (`Σ step()`), and an
all-idle pass composes a *single* `poll()` over every participant's `wait`
interests — `fd = -1` is deadline-only, `wait_ns` caps the wait. A participant
with thread-arriving work can hand the pump an **eventfd** and cross-thread
wakes land in the same union poll. That closes the threads↔pump bridge.

## The grammar (proposed — Lars's gate)

```koru
// Declare + attach consumers — the `default` reference form,
// same shape as std/store(name) ! field / std/pump(name) ! step
std/channel(ch)                    // ch: declared channel name
! recv v |> handle(v: v)           // standing consumer — compiled into a unit
! closed |> shutdown()             // close arm

// Chain steps — same family as std/store:insert / std/store:take
std/channel:send(ch, 42)
| ok |> ...
| full |> ...                      // buffered full — or, under pump, wait interest
| closed |> ...

std/channel:recv(ch)
| some v |> ...
| none |> ...
| closed |> ...

std/channel:close(ch) | ok |> ...
```

Capacity and the consumer's ring instance remain open spellings —
`MpmcRing` is comptime-generic in Zig (`MpmcRing(u64, 1024)`), so
`channel(T, n)` wants the same instantiation mechanism. `rings.kz` today
exports `*anyopaque`+`u64` convenience tors plus a documented typed
pattern (`rings.kz:196-225`) — the channel surface should be typed from day
one, not inherit the untyped shim.

## The element type is a proto name (integration — Lars's direction)

`std/proto` is the nominal-type registry: `std/proto(Player) { health:
Health, hp: f32 }` declares a compile-time identity, layout-silent, and the
first consumer derives the layout (`koru_std/proto.kz:10-26`). `std/store`
and `std/list:new` already drink from that registry (`store.leaf.kz`,
`list.new.kz` read `// proto` markers and live declarations). The channel is
the same consumer act:

```koru
std/proto(Input) { key: Key, ts: f64 }
std/channel(inbox: Input, 256)      // element type = registry entry
```

Three things fall out:

- **Spelling solved.** `name: Type` is proto's own field grammar; the type
  argument is a name, not a type expression.
- **Layout for free.** The channel synthesizes the ring's element struct
  from the proto entry — compound payloads (the realistic case) work from
  day one.
- **Nominal channels.** Proto's ruling is affinity-by-name, never structural
  coupling — `chan Health` vs `chan Score` never interchange, `send` into
  the wrong channel refuses at compile time. Go cannot say this. And a
  proto-typed store row flows into `channel:send` without repacking.

Boundary, honestly: proto's vocabulary is scalars + compounds. Channels of
opaque pointers/handles sit outside it — a pointer-terminal rung, or stay
off-proto. A possible second rung, named not built: `std/channel:i64(Inbox)`
minting a *channel type* as a terminal, the way `std/proto:i64(Port)` mints
a scalar.

`! recv` arms are **competing consumers** — each value goes to one consumer,
Go-true. Broadcast (every consumer sees every value — the thing taps echoed)
is a deliberately separate arm kind, flagged as an open question rather than
baked in.

## Pump join — free by convention

`std/channel` emits `<ch>-step` / `<ch>-live` / `<ch>-wait` verb units, the
same convention stores already use (`pump.kz:30-31`). Then:

```koru
std/pump(main)
! step |> ch-step()
! live |> ch-live()
! wait i |> ch-wait(i: i)
```

Verb meanings for a channel participant:

- `step` — one drain pass: each declared consumer attempts `dequeue` once
  per pass; returns items moved. (Progress = movement.)
- `live` — `0` once closed **and** drained; `1` otherwise.
- `wait(i)` — `{fd: -1, wait_ns: backoff}` for same-thread re-poll; a real
  `fd` (eventfd) when a worker thread must wake the pump.

**This is also the `select` answer.** Joining two channels to one pump, each
with its own `! recv`, is program-level select — statically resolved at the
join sites, no runtime multi-wait construct. Go compiles `select` to a
runtime `selectgo`; Koru compiles it to join order. Per-flow select (one
flow waiting on two channels inline) has no proven spelling — named frontier,
not claimed.

## The three "block" tiers

| Tier | Mechanism | Go analog | Status |
|---|---|---|---|
| Non-blocking arms | `full`/`none`/`closed` branches | `select` + `default` | **grounded today** |
| Cross-thread park | `std.Thread.Futex` wait/wake in the `~proc|zig` impls | `gopark`/`goready` | grounded mechanism, unbuilt surface |
| Same-thread pump | `step` returns 0 → `wait` → re-step; continuation is the pass | — (Go has no analog) | grounded machinery, unbuilt surface |

The futex tier is the honest Go-parity engine: Go's channel is a mutex + wait
queues internally, so a Vyukov CAS fast path in front of a futex park is the
*same* contention story with a lock-free head — the shootout is real.

**The named frontier — deferred resume.** Effect resume is synchronous
(`400_132`, `670_060`): a handler must produce the resume value *at fire
time*. A flow that fires `recv` on an empty channel and parks *mid-flow*,
resumed passes later by the pump, needs "suspend now, resume later" — a
mechanism the language does not have. Two candidate shapes if we want it:
(a) a deferred-resume effect kind (real machinery in `src/`), or (b) the
brokered form — send/recv post requests into the channel participant and the
`| ok` continuation fires on a later pass (also new machinery — continuations
today run to completion per invocation). **Unmeasured, deliberately not
designed here** — Tier-1 futex + Tier-2 pump cover every Go program shape
worth benchmarking without it.

**Rendezvous (cap 0)** is the same frontier in miniature: a true Go
unbuffered send waits for the consumer. With futex + a cap-1 slot this is
implementable today (send parks until taken); the pure effect-pair spelling
(`! offered v -> ack` cross-wired to `! taken -> v`) is the elegant variant
and waits on the deferred-resume question.

## Go parity table

| Go | Koru (proposed) | Engine |
|---|---|---|
| `make(chan T)` | `std/channel(ch)` cap 0 | futex handshake / effect pair |
| `make(chan T, n)` | `std/channel(ch)` cap n | `MpmcRing` CAS |
| `ch <- v` | `send \| ok \| full \| closed` | arm-first; park under pump/futex |
| `<-ch` | `recv \| some v \| none \| closed` | arm-first |
| `close(ch)`; `v, ok` | `close`; `\| closed` arm | atomic flag owned by channel — `rings.kz` untouched |
| `select` | join all channels to one `std/pump` | union `poll()` |
| `range ch` | `! recv` standing consumer | generated consumer unit |
| — | `! each`-style broadcast | open question — beyond-Go |

Reads better than Go, honestly: `closed` is a named arm, not the
zero-value-plus-`ok` idiom; `full`/`none` are first-class where Go needs
`select`+`default` boilerplate. Reads worse: per-flow `select` is a frontier.

## What changes in the tree

- **`koru_std/channel.kz`** — new module: `default` join site, `send`/`recv`/
  `close` transforms, verb-unit emission. The only new file.
- **`koru_std/rings.kz`** — untouched. `closed` is channel semantics, not
  queue mechanics; the flag lives in the channel's generated state.
- **`koru_std/pump.kz`** — untouched. Verb-unit convention already covers it.
- **`src/`** — untouched for Tiers 0–2. Deferred resume (if ever wanted) is
  the only piece that reaches the compiler.

## Done-gates

1. `tests/regression/600_STDLIB/699_CHANNEL/` — next free slot under
   `600_STDLIB`. MUST_RUN pins: buffered roundtrip; `full`/`none`/`closed`
   arms each hit; send-after-close refusal; close-then-drain; two consumers
   competing on one channel (deterministic oracle in `expected.txt`); a
   pump-joined two-channel program (the select-equivalent); futex-parked
   recv across `worker.spawn` threads.
2. `koru-benchmarks/suites/channels/` — the showoff artifact: prime-sieve
   pipeline (Go's own channel showcase — one goroutine per prime) against a
   Koru version with one pump participant per prime. Go reference +
   `expected.txt` oracle + `bench.sh` column, same board format as
   `osprey-compute-kernels`. The comparison writes itself: N goroutines vs N
   participants on one thread.
3. On ruling: seal as `challenges/024_*.md`, `kind: commission` — convergent
   work, one right answer, appears under open commissions.

## Open questions for the gate

1. ~~Type spelling~~ — **answered by proto**: the element type is a registry
   name (`std/channel(inbox: Input, 256)`). Remaining sliver: the capacity
   spelling (`(name: T, n)` vs an arg of its own) and whether capacity-0
   needs a spelling at all or is just `n` absent.
2. `! recv` competing vs `! each` broadcast — one arm kind or two?
3. Rendezvous now (futex handshake) or after the first board?
4. Does `send` with no consumer under pump ever refuse at compile time, or is
   an unrunnable program the author's problem? (The pump's `live` contract
   can detect "blocked forever" at runtime — a compile-time refusal needs
   reachability we don't have.)
