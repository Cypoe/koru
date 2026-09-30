// A ring whose element proto carries an owned leaf must refuse: the slot
// moves bytes with no custody edge, so `*mod:Type<state!>` inside the
// element is a debt the ring cannot account for. The channel is the
// consumer that transits owned leaves (699_031). Leaf-level twin of
// 320_171 (phantom-typed element refused).
import std/proto
import std/rings
import app/lib/res

std/proto(Env) {
    r1: *app/lib/res:Resource<owned!>
}

std/rings:new(moves, capacity: 8) { env: Env }
