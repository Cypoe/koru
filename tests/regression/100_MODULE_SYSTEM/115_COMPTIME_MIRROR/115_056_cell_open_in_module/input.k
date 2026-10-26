// MIRROR of 460_001_cell_open_run_hibernate: a `std/cell:open` whose proto,
// register and invocation all live in an imported module.
//
// open's transform resolves its shape argument against the program's
// std/proto decls — the check that matters here is whether that scan sees a
// proto declared on the module side of the boundary, and whether the cell!
// obligation the `| cell` arm introduces discharges in module-local code.
import app/lib

app/lib:run()
