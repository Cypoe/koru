// Pins std/json:parse — the `[]{...}` element-object schema shape. The
// destructure's `[]{ id: i64, ... }` is schema text, not an emitted type:
// the transform must rewrite leaf type_text to the generated __JP struct
// spellings so the generic destructure emitter never splices raw schema
// text as a Zig type annotation. (Before the fix, emitted code declared
// `const items: []{id: i64, ...} = ...` — invalid Zig.) Element leaves do
// not bind scalars; the array field binds and elements index through it.

import std/io
import std/json

// array of objects, one carrying a nested object
std/json:parse(input: "{\"items\":[{\"id\":1,\"name\":\"ada\",\"meta\":{\"note\":\"first\"}},{\"id\":2,\"name\":\"bob\",\"meta\":{\"note\":\"second\"}}],\"total\":2}")
| malformed { message, offset } |> std/io:print.ln("BAD {{ offset:d }}: {{ message:s }}")
| ok _:{ items: []{ id: i64, name: string, meta: { note: string } }, total: i64 } |> std/io:print.ln("{{ items[0].name:s }}:{{ items[0].id:d }} {{ items[0].meta.note:s }} {{ items[1].name:s }}:{{ items[1].id:d }} total={{ total:d }} len={{ items.len:d }}")

// empty array + undeclared keys inside elements ride the validating skipper
std/json:parse(input: "{\"items\":[],\"total\":0,\"junk\":{\"a\":[1,2]}}")
| malformed { message, offset } |> std/io:print.ln("BAD2 {{ offset:d }}: {{ message:s }}")
| ok _:{ items: []{ id: i64, name: string }, total: i64 } |> std/io:print.ln("empty len={{ items.len:d }} total={{ total:d }}")

// malformed element routes to malformed
std/json:parse(input: "{\"items\":[{\"id\":1,\"name\":}],\"total\":1}")
| malformed { message, offset } |> std/io:print.ln("BAD3 {{ offset:d }}: {{ message:s }}")
| ok _:{ items: []{ id: i64, name: string }, total: i64 } |> std/io:print.ln("FAIL3 {{ items.len:d }} {{ total:d }}")
