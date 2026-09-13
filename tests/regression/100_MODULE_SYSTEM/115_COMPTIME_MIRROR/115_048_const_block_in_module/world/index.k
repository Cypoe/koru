// A `const {}` block living in an IMPORTED module. The JS emitter's
// declaration splice must descend `module_decl` items the way the host-line
// and inline-code splices do — otherwise these names are referenced by the
// module's own handlers and never declared (ReferenceError at run time).
// 010_006 pins the same-file road.
const {
    THRUST: 220.0[f32]
    DRAG: 0.60[f32]
}

pub tor push { vx: f32 } -> f32

push -> vx * DRAG + THRUST
