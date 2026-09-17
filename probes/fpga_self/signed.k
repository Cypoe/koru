import std/proto
import std/refine
import std/kernel
import std/io

std/proto(Sample) {
    value: i64
}

std/refine(Sample)|fpga {
    value: i64 & >=-128 & <=127
}

std/kernel:shape(Sample) {
    value: i64,
}

std/kernel:init(Sample) {
    { value: -60 },
    { value: 100 },
}
| kernel k |> std/kernel:self|fpga { k.value *= 2 }
| computed c |> std/io:print.blk {
        v[0]={{ c[0].value:d }},{{ c[1].value:d }}
    }
