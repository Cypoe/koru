# 014_fleet_protocol

The fleet verbs' per-operation floor cost — what custody itself costs, below
the turn machinery `013_cell_node` measures. Each arm loops one verb TURNS
times and reports total wall time:

| arm | what it isolates |
|---|---|
| `owner` | the routing probe — one record read, no writes |
| `claim+release` | the `createNew` CAS round trip: ensureDirs + failed read + epoch read + exclusive create + record write + epoch bump + delete |
| `renew` | locked lease refresh — lock dir + record read + tmp+rename + unlock |
| `seize` | serialized takeover — lock dir + record read + epoch bump + tmp+rename + unlock |
| `baseline.zig` | identical syscall sequences, no runtime — the speed of light for this protocol shape |

The comparator set is declared: celld is **not** in the set — there is no
parity workload yet, and none of these numbers claim anything about it. The
question answered is narrower and prior: is the shared-floor protocol's per-op
price dominated by syscalls (the design is honest) or by our own machinery
(the stack is paying rent the floor doesn't owe)?

## Correctness gate

The `epochs/` counter only moves when a claim or seize actually lands. After
the run: `epochs/cycle == TURNS` (each iteration claimed) and
`epochs/seizable == TURNS + 1` (one seed claim + TURNS takeovers). A verb
that silently degraded into a cheap arm shows up as a wrong counter, not a
suspiciously fast number. Stray `held-by`/`free`/`failed`/`contended` lines
also fail the gate.

## Run

```sh
./run.sh
```

Numbers are per-run wall time; per the bench rules, only a min across runs
on a calm machine is a claim.
