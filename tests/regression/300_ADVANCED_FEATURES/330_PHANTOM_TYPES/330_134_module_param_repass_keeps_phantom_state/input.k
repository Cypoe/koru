// PIN — a phantom param re-passed inside its own module keeps its
// tracked state. Measured 2026-09-18: it refuses,
//   KORU030 expected 'app.m:live' but got 'm:live'
// — the param declaration canonicalizes the state to the file-stem
// name (`m:live`) while the call-site expectation uses the logical
// module name (`app.m:live`). Same `*Handle<live>` spelling in one
// file, two state names.
//
// The union form `<a|b>` and `@label` loop re-entry fail the same root
// (measured: 'expected jev:greedy|jev:chaotic got app.jev:greedy' at
// re-entry vs 'expected app.jev:greedy got jev:greedy' at head calls)
// — the @label case additionally blocks discharge inside its scope, so
// a module-internal judged loop cannot be written at all.
import app/m

app/m:make(): h |> app/m:twice(h) |> app/m:done(h)
