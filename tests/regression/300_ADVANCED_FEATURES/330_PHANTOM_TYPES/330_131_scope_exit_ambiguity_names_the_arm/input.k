// An obligation with several disposers that reaches a `! each` scope exit
// undisposed is refused at the scope arm (`! each ...`), not the flow head —
// "Discharge explicitly" tells the author the remedy and the caret says where.
import std/control
import app/fs2
for(0..3)
! each _ |> app/fs2:open(path: "x"): f |> app/fs2:lock(file: f): g
| done |> _
