// The panic variant of the `-> T` + `| branch` collision: `| ?!badjob` is
// an armable union member, and the bare return's share of that union emits
// an invalid empty tag — raw-Zig death, not just unreachable vocabulary.
// The wall covers panic arms too (210_309 pins the named-branch mix).
import std/io

tor probe { n: u32 } -> u32
| ?!badjob i64

proc probe|zig {
    return n;
}

probe(n: 3): r |> std/io:print.ln("got {{ r:d }}")
