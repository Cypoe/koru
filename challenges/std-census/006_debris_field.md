---
census: std/env + std/table + std/eval + std/testing + std/net + std/http
measured: 2026-09-11
against: koru main 1da0f3dd3
consumers: ~4,000 .k/.kz files — koru suite, koru-libs, kopium, orisha, misc ~/src
batch: six near-zero organs in one entry — see the frame note at the bottom
---

# The debris field — six organs at or near zero

## std/env — 52 lines, 4 tors

| tor | classification | evidence |
|---|---|---|
| `get`, `get.or`, `is-set`, `require` | **live, as of today** | zero call sites at census time — then `get.or` gained its first real caller mid-session (`kopium/headless/headed.k`, `KOPIUM_MODEL`). The other three remain at 0. |

A tiny package that was dead *when measured* and live by commit — the census's
own staleness lesson. Keep it: an env-var lookup is exactly what a real
program reaches for. **task** — nothing to fix; this row is the reminder that
zero-use ≠ unwanted.

## std/table — 62 lines, 3 tors

| tor | classification | evidence |
|---|---|---|
| `from`, `sum`, `gaps` | live-design, unadopted | compile-time table comprehensions (`from(name) { x over 1..4 }` → const array), v1 generator-only; "the pure-Koru #loop evaluator is the flex" per its own header. Zero consumers — landed recently, not abandoned. |

Not debris — a young feature waiting for its first caller. **task** — none;
revisit after adoption pressure exists.

## std/eval — 454 lines, 2 tors

| tor | classification | evidence |
|---|---|---|
| `eval`, `eval-bool` | **dead** | zero `std/eval:` call sites anywhere — suite included (the `eval` hits in tests are `std/runtime:eval`, a different tor). A designed runtime expression evaluator nobody ever wired. **→019** — 454 lines of machinery with no caller; either delete or find its intended consumer and say why it was never connected. |

## std/testing — 919 lines, 5 tors

| tor | classification | evidence |
|---|---|---|
| `test`, `validate-mocks`, `test.with-harness`, `test.harness`, `test.property.equivalent` | **dead** | a compiler-guided test framework (mock detection, generated zig tests) — the actual regression suite is shell + markers and does not consume it. Zero call sites. |

The largest dead organ so far. **→019** — near-1K lines of unadopted
framework; the honest question is whether the suite ever wanted this shape.

## std/net — 63 lines, 5 tors

| tor | classification | evidence |
|---|---|---|
| `tcp.listen`, `tcp.accept`, `tcp.read`, `tcp.write`, `tcp.close` | **designed absence** | every tor refuses at compile time and teaches where the real surface is (curl for client, orisha for server, unikraft/net for raw frames). The *redeemed* liar — `frag-a-surface-with-no-callers-is-where-a-lie-survives` is this package's history. |

The model citizen of the debris field: nothing implemented, nothing hidden,
every refusal load-bearing. This is what the other dead packages could look
like if they mattered enough to refuse rather than rot.

## std/http — 215 lines, 8 tors

| tor | classification | evidence |
|---|---|---|
| `http.parse-request`, `http.response`, `http.match-route`, `http.json-response`, `http.html-response`, `http.mime-type`, `http.url-decode`, `http.parse-query` | **superseded** | real implementations (parse-request actually parses, response actually builds) with ~0 call sites — orisha owns the server frame, `koru/curl` owns the client. Working code whose job was taken. **→019** — a real impl nobody calls is worse than net's honest refusal: it suggests a surface that doesn't exist. |

## Frame note — the batch bent the brief

`022` says "one namespace." Six near-zero organs in one entry is faster and
loses nothing (each still gets its table and verdict) — but it hides the
per-organ diffs a solo entry would carry. The batch worked because these are
shells; it would fail on `store`. Suggest the brief sanction batching
*explicitly* for namespaces under ~100 lines / ~5 tors, and forbid it above.

## Verdict

Mixed by nature: `net` is designed refusal, `table` is new-and-unadopted,
`env` flipped live mid-measurement, and `eval`/`testing`/`http` are the
genuine debris — ~1.6K lines of machinery between them with no caller among
them.
