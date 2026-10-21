// MIRROR of 696_001_ctx_scope_injection: `std/ctx` scope attach (the
// std/ctx:default transform) relocated into an imported module.
//
// ctx splices out at comptime by reading the named store's fields — the
// store and the scoped flow both living in the module is the boundary
// position this mirror exists to pin.
import app/lib

app/lib:run()
