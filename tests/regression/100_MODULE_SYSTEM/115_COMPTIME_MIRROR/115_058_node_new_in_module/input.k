// MIRROR of 450_001_node_borrow_spawn_run_evict_drain: `std/node:new`
// relocated into an imported module.
//
// new is a top-level-item transform — it must stay the invocation head of
// its flow (the transform refuses mid-chain placement itself). Mirroring it
// checks that the node's registry, fleet record and drain all resolve when
// the declaration site lives across the module boundary.
import app/lib

app/lib:run()
