// MIRROR of 460_005_cell_capture_typed_record: a `std/cell:capture`
// transaction whose proto, open and capture all live in an imported module.
//
// capture's transform rewrites its containing flow into a record transaction;
// relocated into a module, the `! as` binding and the `captured { f: expr }`
// blocks must still resolve against the proto-typed record — the shape
// grammar aimed at a cell across the boundary.
import app/lib

app/lib:run()
