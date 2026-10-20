---
type: belief
id: frag-a-cell-commit-is-an-arm-extent
provenance: std/cell + std/fleet construction, 2026-10-20 — materializer
  landed at the capture seam; fleet activation probes the durable floor
ts: 2026-10-20
---

# A cell's commit boundary is the lexical extent of its `! as` arm (belief)

The first materializer for `std/cell` went looking for a place to live and
found the answer was already spelled: `std/cell:capture`'s `! as` arm *is*
the transaction. Its extent is lexical — the record is a local var for the
arm's duration, `std/cell:captured {}` blocks are field-wise assignments
against it, and the flush fires exactly once when the arm's body ends. No
`tx.begin`/`tx.commit` call pair to misplace, no transaction handle to
leak; the scope checker enforces the boundary the same way it enforces
custody. Abandonment is free — exit the arm without reaching the end and
the writes never existed anywhere. `| captured` isn't an after-read so
much as *the* commit: "did the write land" is a branch the program
dispatches on, not a return value it can drop.

The general claim: **durability wants one seam, and the arm extent is the
seam.** A materializer — the flat-file `state.kv` now, SQLite or an object
store later — owns exactly one call site. If the seam ever becomes two
call sites, the semantics changed; watching the seam count is watching
the invariant.

The fleet-side corollary, discovered the same week: **residency is a
cache; the directory is the truth.** `| not-found` means "never existed
anywhere", not "not in memory" — a member lookup miss probes
`<world_root>/<id>/state.kv`, reads the `#shape` header, and rebuilds the
cell. `evict` is hibernation (the file survives); `retire` is death (the
file dies). `spawn` on a dormant id refuses `| resident` — the identity
is taken even when nothing holds it in memory. The map is what the
machine can see right now; the directory is what exists.

First measurement (60 turns, laptop, indicative): durable commit ≈
resident + ~30µs — the materializer costs the file write, not the shape.
The interpreter dispatch (~90µs/turn) dominates; durability is not the
bottleneck at this scale.

## What would correct this belief

- A commit that must span two materializers — the seam is then two
  commit points with a failure window between them, and "atomic" becomes
  a claim the shape can't keep. The planned answer is refusal (partition
  check on the manifest), but a real mixed-store capture would test it.
- A `| conflict` arm — once commits can be rejected (lease fences, epoch
  checks), the after-read splits into landed/refused, and "the arm's end
  is the commit" becomes "the arm's end is the *attempt*".
- Distributed claims — celld's conditional ownership writes fence stale
  writers; single-process custody can't express a stale owner, so the
  fencing requirement is unproven, not absent.
