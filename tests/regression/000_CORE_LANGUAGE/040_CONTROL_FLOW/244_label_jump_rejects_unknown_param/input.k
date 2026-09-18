// PIN — a `@label` jump arg must name a field of the target event. Jump args
// re-seed `<label>_<name>` state vars keyed by ARG NAME; an arg that names no
// field emits an undeclared `loop_<name>` and stage-D reports a raw Zig error
// ("use of undeclared identifier") with no Koru diagnostic. The phantom
// checker refuses it first with KORU043. The same check guards the `#label`
// head call (PARSE006 already refuses bare literals there; this layer catches
// what reaches it — field-access args and named args alike).
import std/io
import app/lib

app/lib:work(j: 1, draft: 7)
| polished out |> std/io:print.ln("{{ out:i32 }}")
| broke |> std/io:print.ln("broke")
