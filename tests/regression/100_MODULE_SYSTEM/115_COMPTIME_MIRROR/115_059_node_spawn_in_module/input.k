// MIRROR of 450_001_node_borrow_spawn_run_evict_drain: `std/node:spawn`
// relocated into an imported module, under a `| node` borrow that is itself
// the node:default transform.
//
// spawn's transform rewrites the invocation head of its flow; mirroring
// checks the spawned-cell custody chain (spawned/resident/held-by arms)
// resolves identically when the site lives across the boundary.
import app/lib

app/lib:run()
