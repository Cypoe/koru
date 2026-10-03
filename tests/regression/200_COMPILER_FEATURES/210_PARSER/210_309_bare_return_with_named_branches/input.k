// A bare return `-> T` and named `|` outcome branches are different
// contracts: `return_type` wins, and every declared `| branch` parses into
// the EventDecl yet can never be armed at a call site — KORU021 reports
// "a bare return has no tags". Declared vocabulary that cannot be spelled
// refuses at the declaration, not downstream of it. `| ?!` panic arms are
// refused too — they join the outcome union while the bare return emits an
// empty tag (210_310). The legal mix pinned by control: `-> T` + `!`
// effect arms (210_189, pump `! ?polled` decls) — yields, not outcomes.
import std/io

tor probe { n: u32 } -> u32
| failed string
| blocked

proc probe|zig {
    return n;
}

probe(n: 3)
| ok r |> std/io:print.ln("got {{ r:d }}")
