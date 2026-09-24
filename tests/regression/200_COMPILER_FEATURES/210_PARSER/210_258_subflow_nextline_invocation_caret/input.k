// PINS: Flow.location on the `name =` + next-line-invocation subflow path
// names the head invocation's own line. The transform refusal (regex match
// takes an input argument) rides flow.location — before head-line semantics
// this caret landed past the flow.
import std/io
import std/regex

pub tor tick { n: i64 }

tick =
    std/regex:match

tick(n: 1)
