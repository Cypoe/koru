// PINS: a `: _` capture inside a subflow discards the step result — it must
// never materialise as `const _ = <call>` (illegal Zig) or leave a `_ = &_`
// mark-used behind. Both positions are covered: the head invocation of the
// impl (`noop(): _`) and a mid-chain `|>` step.
import std/io

tor noop { } -> i64
noop -> 7

tor head { } -> i64
head = noop(): _ |> noop(): n -> n

tor mid { } -> i64
mid = noop(): a |> noop(): _ |> noop(): b -> a + b

head(): h |> mid(): m |> std/io:print.ln("{{ h:d }} {{ m:d }}")
