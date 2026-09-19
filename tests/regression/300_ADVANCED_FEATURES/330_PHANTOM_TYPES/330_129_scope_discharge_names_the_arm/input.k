// Discharging an OUTER-scope obligation inside a `! each` scope boundary is
// refused at the ARM that discharges it — `! each _ |> app/fs:close(file: f)`
// — not at the flow head. The arm owns the error.
import std/control
import app/fs
app/fs:open(path: "outer.txt"): f |> for(0..3)
    ! each _ |> app/fs:close(file: f)
