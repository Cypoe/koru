// MIRROR for `std/rings:new`, `std/rings:enqueue` and `std/rings:dequeue`:
// declared and used from an imported module. `app/lib` owns the ring and
// both verbs; the entry composes its pub tors by qualified name. The
// transform emits generated units (`__rings_*`) and this is the test that
// can see whether they qualify through the module's import-derived name —
// the entry file collapses file-name and module-name into one, so the
// 320_090-era controls cannot tell a correct qualifier from a lucky one.
import app/lib

app/lib:push(v: 7)
| ok |> app/lib:push(v: 8)
    | ok |> app/lib:pop() |> app/lib:pop()
    | full |> app/lib:pop()
| full |> app/lib:pop()
