// Pins that a subflow impl body invoking a Source-param, effect-branching
// tor emits the arg as the typed `__koru_ast.Source{...}` literal — never
// the raw capture text spliced into the struct field (`.source = v: 40[i64]`
// is Koru syntax inside Zig, an immediate backend rejection). Two emission
// sites carry the defect class: emitArgs falls back to `arg.value` when the
// callee decl misses its event-decl table (transforms resolve elsewhere),
// and the subflow-head call writer in visitor_emitter had no source branch
// at all. The `| captured c` arm also pins that a wildcard `*` payload is a
// payload — the prong binds `|c|`, or the produced value references an
// unbound name.

import std/io

pub tor get-input {} -> i64

get-input = capture { v: 40[i64] }
! as a |> captured { v: a.v + 1 }
| captured c -> c.v

get-input(): s |> std/io:print.ln("{{ s:d }}")
