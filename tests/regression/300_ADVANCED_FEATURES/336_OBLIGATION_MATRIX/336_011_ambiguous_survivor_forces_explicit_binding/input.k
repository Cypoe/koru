// GUARD — ambiguity must keep forcing an explicit binding.
//
// `merge` consumes two same-typed handles and mints one; there is no sole
// survivor, so `a` must NOT continue (the result could be `a`, `b`, or new).
// The continuation rule is arity-bounded: name the survivor only when one is
// left. Here two were consumed, so `a` is spent and `close(a)` must be refused.
//
// Green today and must STAY green when the continuation rule lands — this is
// the negative space that keeps the rule from over-applying.
import app/held
import std/io

app/held:open()
| opened a |> app/held:open()
    | opened b |> app/held:merge(a, b): m |> app/held:close(h: a)
    | err e |> std/io:print.ln("err: {{ e:s }}")
| err e |> std/io:print.ln("err: {{ e:s }}")
