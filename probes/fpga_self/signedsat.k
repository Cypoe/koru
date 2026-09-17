import std/proto
import std/refine
import std/kernel
import std/io

std/proto(Sample) {
    value: i64
}

std/refine(Sample)|fpga {
    value: i64 & clamp(-100,100)
}

std/kernel:shape(Sample) {
    value: i64,
}

std/kernel:init(Sample) {
    { value: -60 },
    { value: 80 },
}
| kernel k |> std/kernel:self|fpga { k.value *= 2 }
| computed c |> std/io:print.blk {
        v[0]={{ c[0].value:d }},{{ c[1].value:d }}
    }
