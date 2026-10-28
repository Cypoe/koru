import std/control
import std/io
import app/fs
app/fs:open(path: "outer.txt"): _ |> for(0..3)
    ! each i |> std/io:print.ln("{{ i:d }}")  // Loop body, obligation flows through
