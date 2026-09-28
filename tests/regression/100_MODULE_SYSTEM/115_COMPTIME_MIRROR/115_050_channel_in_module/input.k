// MIRROR for `std/channel:new`, `std/channel:send`, `std/channel:recv`,
// `std/channel:close`, `std/channel:default` and `std/channel:consume` —
// all declared and used from an imported module. `app/lib` owns two
// channels: `inbox` carries a `! reading`/`! closed` join drained by a
// module-side pump, `outbox` answers plain send/recv/close. The transforms
// emit generated units (`__channel_*`) and this is the test that can see
// whether they qualify through the module's import-derived name — the
// entry file collapses file-name and module-name into one, so the 699_*
// controls cannot tell a correct qualifier from a lucky one.
import app/lib

app/lib:push(i: 7)
| ok |> app/lib:push(i: 8)
    | ok |> app/lib:post(i: 3)
        | ok |> app/lib:pull() |> app/lib:pull()
            |> app/lib:shutdown() |> app/lib:seal() |> app/lib:go()
        | full |> app/lib:seal()
        | closed |> app/lib:seal()
    | full |> app/lib:seal()
    | closed |> app/lib:seal()
| full |> app/lib:seal()
| closed |> app/lib:seal()
