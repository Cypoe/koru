// Test: the cell state surface — shape-derived field manifest.
//
// `std/cell:open` bakes the proto block into a "name:type;..." manifest at
// transform time (the proto's own field grammar already ran upstream; the
// transform only splits lines). `get`/`set` validate field names against the
// manifest — a typo'd field names the shape (`unknown-field`), a value that
// won't coerce names the expected type (`type-mismatch`), and a declared-
// but-never-written field is `unset`, distinct from absent.
//
// The state is in-memory: hibernate loses it. That is the honest seam —
// a materializer (SQLite/DuckDB per the [X] field annotations still being
// designed) plugs in where `state` lives.

~import std/io
~import std/cell
~import std/proto
~import std/runtime

~std/proto(room_state) {
    visits: u32
    name: string
    awake: bool
}

~pub tor greet { name: string } -> string
~greet -> "hello {{ name:s }}"

~std/runtime:register(scope: "cell") {
    greet(5)
}

~std/cell:open(room_state, id: "assistant")
| cell c |> std/cell:fields(c): fl |> std/io:print.ln("shape: {{ fl:s }}")
  |> std/cell:get(c, field: "visits")
    | value v |> std/io:print.ln("visits = {{ v.int:d }}")
    | unknown-field e |> std/io:print.ln("no field {{ e.field:s }}")
    | unset u |> std/io:print.ln("visits unset")
  |> std/cell:set(c, field: "visits", value: "41")
    | set |> std/io:print.ln("visits set")
    | unknown-field e |> std/io:print.ln("no field")
    | type-mismatch t |> std/io:print.ln("mismatch")
  |> std/cell:get(c, field: "visits")
    | value v |> std/io:print.ln("visits = {{ v.int:d }}")
    | unknown-field e |> std/io:print.ln("no field")
    | unset u |> std/io:print.ln("unset")
  |> std/cell:set(c, field: "vists", value: "1")
    | set |> std/io:print.ln("vists set")
    | unknown-field e |> std/io:print.ln("unknown: {{ e.field:s }} (shape: {{ e.shape:s }})")
    | type-mismatch t |> std/io:print.ln("mismatch")
  |> std/cell:set(c, field: "visits", value: "abc")
    | set |> std/io:print.ln("set")
    | unknown-field e |> std/io:print.ln("no field")
    | type-mismatch t |> std/io:print.ln("{{ t.field:s }} wanted {{ t.expected:s }}")
  |> std/cell:set(c, field: "name", value: "assistant-01")
    | set |> std/io:print.ln("name set")
    | unknown-field e |> std/io:print.ln("no field")
    | type-mismatch t |> std/io:print.ln("mismatch")
  |> std/cell:set(c, field: "name", value: "assistant-02")
    | set |> std/io:print.ln("name reset")
    | unknown-field e |> std/io:print.ln("no field")
    | type-mismatch t |> std/io:print.ln("mismatch")
  |> std/cell:get(c, field: "name")
    | value v |> std/io:print.ln("name = {{ v.text:s }}")
    | unknown-field e |> std/io:print.ln("no field")
    | unset u |> std/io:print.ln("unset")
  |> std/cell:set(c, field: "awake", value: "true")
    | set |> std/io:print.ln("awake set")
    | unknown-field e |> std/io:print.ln("no field")
    | type-mismatch t |> std/io:print.ln("mismatch")
  |> std/cell:get(c, field: "awake")
    | value v |> std/io:print.ln("awake = {{ v.flag:any }}")
    | unknown-field e |> std/io:print.ln("no field")
    | unset u |> std/io:print.ln("unset")
  |> std/cell:run(c, source: "greet(name: \"assistant\")")
    | result r |> std/io:print.ln("cell said: {{ r.bound:s }}")
    | defined d |> std/io:print.ln("defined")
    | unhandled-branch u |> std/io:print.ln("unhandled")
    | exhausted e |> std/io:print.ln("exhausted")
    | parse-error e |> std/io:print.ln("parse-error")
    | residue r2 |> std/io:print.ln("residue")
    | validation-error v |> std/io:print.ln("validation-error")
    | shape-error s |> std/io:print.ln("shape-error")
    | event-denied e |> std/io:print.ln("denied")
    | dispatch-error e |> std/io:print.ln("dispatch-error")
    | scope-not-found s3 |> std/io:print.ln("scope missing")
  |> std/cell:hibernate(c) |> std/io:print.ln("assistant hibernated")
