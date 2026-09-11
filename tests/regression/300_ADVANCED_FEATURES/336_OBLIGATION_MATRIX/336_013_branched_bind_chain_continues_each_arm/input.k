// RULING GUARD (2026-09-11): a BRANCHED `: bind`-head chain continues in
// every arm.
//
// `make(): h` head-binds a handle; `t1(h)` consumes and re-mints it; `split(h)`
// consumes the re-minted handle and branches. Each arm's `close(h)` means that
// arm's re-minted handle. This is the seam between the continuation pass and
// the chain-pun thread: the pun thread's walk is linear, so it claims the
// pre-branch consume (`t1`) but cannot reach the in-arm references; the
// continuation pass must therefore run FIRST and own every consume-continuation.
// Without that layering this is KORU030 on the stale `h` in each arm.
//
// See concepts/frag-a-consumed-handle-should-continue-its-binding.
import app/held
import std/io

app/held:make(): h |> app/held:t1(h) |> app/held:split(h)
    | yes _ |> app/held:close(h) |> std/io:print.ln("yes arm continued")
    | no _ |> app/held:close(h) |> std/io:print.ln("no arm continued")
