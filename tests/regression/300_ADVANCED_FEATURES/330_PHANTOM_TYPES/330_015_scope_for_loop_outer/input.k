import std/control
import std/io
import app/fs
app/fs:open(path: "outer.txt"): outer_f |> for(0..3)
    ! each i |> std/io:print.ln("{{ i:d }}")  // outer_f is suspended here (@scope), disposed in done
