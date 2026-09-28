// MIRROR for `std/testing:assert.eq` and `std/testing:assert.contains`:
// multi-Expression transform invocations inside an imported module's tor.
// `app/lib` owns the checks; the entry composes by qualified name. A
// transform that resolves its emitted check only against the entry file's
// scope is invisible to the 395_014 run-flow control — this is the test
// that can see it.
import app/lib

app/lib:checks()
