# 013_cell_node

The Orleans counter-grain workload, on koru cells. Orleans' persistence
microbench measures, per grain call: method dispatch + `WriteStateAsync`
(durable write). The koru spelling of the same shape:

```
| cell c |> std/cell:run(c, source: "touch(k: 1)")     <- the grain call: a
  | result _ |> std/cell:capture(c, shape: counter)      turn through the cell's
    ! as s |> std/cell:captured { hits: s.hits + 1 }     interpreter, then a
                                                         transaction whose leaf
                                                         end IS WriteStateAsync
```

The transaction's commit boundary is the `! as` arm's end — the same seam a
real materializer (SQLite, object store) will own. The one here is flat-file:
`state.kv` inside the cell's world dir (`<world_root>/<id>/`).

## Arms

| arm | what it isolates |
|---|---|
| `resident` | worldless node — dispatch + capture, no materializer |
| `durable` | world-mounted node — same turns, every commit is a file write |
| `durable+sync` | same commits, `fs:sync` after each — the fsync-grade ack level celld's storage puts carry |
| `activation` | evict + member-lookup cycles — hibernate, then re-materialize from `state.kv` (Orleans DeactivateOnIdle + wake-on-call) |
| `baseline.zig` | identical semantics, no interpreter — the speed of light for the I/O shape |

The Zig baseline is the honest floor: it pays the same file-write cost per
commit and nothing else, so the gap between `durable` and `baseline durable`
is the interpreter + custody + materializer stack's real price.

## The celld comparator

The same counter workload ran against Deno celld 0.6.2 (`examples/counter`,
`celld dev` in docker, wrk over HTTP): the durable turn is ~4.6ms p50
sequential, ~789 rps pipelined at 8 connections, against a ~172µs wire+V8
floor measured with a no-DO echo path. Sequential turns are exactly-once
(101/101); concurrent runs showed ~1 duplicate turn per connection — the
at-least-once delivery its docs admit on ambiguous paths.

Two named asymmetries in the comparison, not one number: celld pays an HTTP
front we don't have, and its acknowledged writes are fsync-grade SQLite
commits while `durable` is a buffered write (`durable+sync` spells the same
level — on this Mac, APFS fsync costs only ~7µs in the baseline, so the
premium is small; celld's 4.6ms is mostly its own DO/SQLite/replication
machinery plus virtio-fs, not the sync itself).

## Correctness gate

Each grain must show `hits == TURNS` at the end — read back through the
node. A stage that silently never ran shows up as a wrong checksum, not a
suspiciously fast number.

## Run

```sh
./run.sh
```

## What this is not (yet)

- No epoch fencing — single-process custody; celld's conditional ownership
  writes exist to fence STALE writers, which this model can't express yet.
- No peer routing — `std/node` is one registry per process.
- `capacity` evicts an ARBITRARY resident on activation overflow, not LRU.
