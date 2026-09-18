// PIN — a `@label` jump may re-seed a SUBSET of the target's fields: omitted
// params carry over their `<label>_<name>` state vars, which is what the vars
// are `var` for (`@label` with no args at all is the full carry-over case and
// already legal). Emission fills every param of the re-call from its state
// var and marks only re-seeded vars `var` — an unfilled param once emitted a
// partial struct ("missing struct field") and an all-fields-`var` seed tripped
// "local variable is never mutated".
//
// `tag` is seeded once and never named by the jump; reaching `done` requires
// three re-seeds of `count`, so "hello" arriving proves the carry-over.
import std/io
import app/lib

app/lib:work(count: 0, tag: "hello")
| polished d |> std/io:print.ln("{{ d:s }}")
| broke |> std/io:print.ln("broke")
