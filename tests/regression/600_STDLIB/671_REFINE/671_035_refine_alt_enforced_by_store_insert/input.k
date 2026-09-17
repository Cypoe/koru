// Test: the set reaches the SECOND consumer, which builds its insert
// guard through the shared predicate — and whose AST arrives by
// serialization, so this also pins that a set survives program.ast.json.
// `a.mode: 2` commits; `a.mode: 9` is a non-member and produces into the
// branch carrying the column spelling.
//
// Expected: runs clean — `committed` then `rejected a.mode`.
import std/proto
import std/refine
import std/store
import std/io

std/proto:i64(Mode)

std/proto(Sample) {
    mode: Mode
}

std/refine(Sample) {
    mode: Mode & 1 | 2 | 3
}

std/store:new(reg, capacity: 4) { a: Sample }

std/store:insert(reg) { a.mode: 2 }
| row r |> std/io:print.ln("committed")

std/store:insert(reg) { a.mode: 9 }
| violated f |> std/io:print.ln("rejected {{ f:s }}")
