import std/proto
import std/refine
import std/kernel
import std/io

std/proto(Sample) {
    value: i64
}

std/refine(Sample)|fpga {
    value: i64 & clamp(0,255)
}

std/kernel:shape(Sample) {
    value: i64,
}

std/kernel:init(Sample) {
    { value: 200 },
    { value: 60 },
}
| kernel k |> std/kernel:self|fpga { k.value *= 2 }
| computed c |> std/io:print.blk {
        v={{ c[0].value:d }},{{ c[1].value:d }}
    }
