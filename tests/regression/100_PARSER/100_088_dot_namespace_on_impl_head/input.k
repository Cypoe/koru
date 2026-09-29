// Pins: `.` is not a namespace separator on an impl-assignment head either.
// Call sites refuse `std.io:` under KORU035 (rejectDotNamespace); the impl
// head `std.compiler:coordinate = ...` reaches parseQualifiedPath unswept,
// and the old spelling silently overrides the pipeline. One rule, one more
// site: spell it `std/compiler:coordinate`.
import std/io

std.compiler:coordinate = error "sanctioned pipeline only"

tor greet {}

greet()
