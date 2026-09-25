// PINS: a proto field line names ONE field. `rpm: i32 serial: string` reads
// `serial: string` as a second field fused to `rpm`'s line, and the refusal
// names the fused fragment — proto fields are one `name: type` per line.
import std/types

std/types:proto(Fused) {
    rpm: i32 serial: string
}
