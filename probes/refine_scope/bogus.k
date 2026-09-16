import std/proto
import std/refine
import std/io

std/proto(Sample) {
    value: i64
}

std/refine(Sample)|bogus {
    value: i64 & <=255
}

std/io:print.ln("never")
