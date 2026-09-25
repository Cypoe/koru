// PINS: a step annotation is only kept on invocation and label steps — on any
// other step kind the peel path frees it without a diagnostic. `[with]` on a
// branch-body `_` terminal vanishes in silence: an annotation the author
// wrote and the compiler swallowed. Refuse annotations on step kinds that
// cannot carry them.
import app/probe

app/probe:probe(msg: "x")
| ok _ |> [with]_
| err _ |> _
