import std/control
import std/io
import app/fs
app/fs:open(path: "outer.txt"): f |> for(0..3)
    ! each i |> std/io:print.ln("{{ i:d }}")
    | done |> app/fs:close(file: f)
