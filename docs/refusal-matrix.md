# The Refusal Matrix
Every refusal the stdlib contracts can emit — a pure projection of the
`refuse(`/`refusal(` sites in `koru_std/*.kz`, grouped by contract and
ranked by measured volume in `friction/corpus.json`. **Do not edit by
hand** — run `python3 friction/contracts.py`.

Snapshot: `a816b9c5c` · 421 refusal sites

## `std/store:query` (7 refusals — fired 67× in the corpus)
- `KORU161` std/store:query requires a store name: query(name)
- `KORU161` std/store:query({s}): the guard names `@{s}`, and that operation has no lowering for this target - a store guard is a Koru expression, and the operations Koru names with `@` are the shared table in codegen_utils.lowerBuiltin
- `KORU161` std/store:query({s}): the sweep body must start with an invocation this rung
- `KORU161` std/store:query({s}): the sweep branch needs a body (`|> ...`)
- `KORU161` std/store:query({s}): the sweep guard names `@{s}`, and that operation has no lowering for this target - a store guard is a Koru expression, and the operations Koru names with `@` are the shared table in codegen_utils.lowerBuiltin
- `KORU161` std/store:query({s}): unknown plural store - no std/store:new({s}, capacity: N) found (query reads a plural container's live rows)
- `KORU161` std/store:query({s}): view member '{s}' has no schema — no std/store:new({s}) found

## `std/store:stored` (22 refusals — fired 53× in the corpus)
- `KORU161` std/store:stored requires a write block: stored {{ store.field: expr }}
- `KORU161` std/store:stored target '{s}' must be a dotted store path (store.field)
- `KORU161` std/store:stored: '{s}' is a capacity-1 value store - write it as {s}.{s}
- `KORU161` std/store:stored: '{s}' is a container store (capacity > 1) - address the row ({s}[handle].{s}, or write through a query branch)
- `KORU161` std/store:stored: '{s}' is not a field of store '{s}'
- `KORU161` std/store:stored: `| cycle` attaches to the [tree]-synthesized parent write - '{s}.{s}' is not the parent column
- `KORU161` std/store:stored: `| cycle` guards the synthesized parent write of a [tree] store - '{s}' is not a [tree] store
- `KORU161` std/store:stored: `| cycle` needs a row-addressed parent write ({s}[handle].parent)
- `KORU161` std/store:stored: a multi-field block addresses columns by a 64-bit mask, and '{s}' has more than 64 columns - write this as chained single-field writes
- `KORU161` std/store:stored: a multi-field envelope addresses ONE row this rung - every target must spell the same row ('{s}')
- `KORU161` std/store:stored: a multi-field envelope writes ONE store this rung ('{s}' vs '{s}')
- `KORU161` std/store:stored: addressing head '{s}' needs a field: store[handle].field
- `KORU161` std/store:stored: branch '{s}' - a guarded parent write answers `|>` (ok) and `| cycle` only
- `KORU161` std/store:stored: envelope target '{s}' must be store.field
- `KORU161` std/store:stored: internal - plural store '{s}' has no generated apply event (create must have run: inserth exists without apply)
- `KORU161` std/store:stored: malformed addressing head '{s}'
- `KORU161` std/store:stored: store '{s}' holds an owned column - a multi-field envelope has no typed zero for its slot (690_064); chain single-field writes instead ({s}[handle].{s}: ... |> stored {{ ... }})
- `KORU161` std/store:stored: store '{s}' is a DRAIN store (ambiguous discharger) - a stored write must evict the old value through the canonical discharger, which its owned column does not have; declare exactly one void discharger for the column type (690_062 pins the write; 690_057/058 pin the drain)
- `KORU161` std/store:stored: unknown store '{s}'
- `KORU161` std/store:stored: unknown store '{s}' - no std/store:new({s}) found
- `KORU161` std/store:stored: write block is empty
- `KORU161` std/store:stored: {s}

## `std/store:insert` (13 refusals — fired 37× in the corpus)
- `KORU161` std/store:insert requires a store name and a row block: insert(name) {{ field: value }}
- `KORU161` std/store:insert({s}): a row block names every column exactly once ({d} given, {d} declared)
- `KORU161` std/store:insert({s}): branch '{s}' - insert answers `| row <binding>`, `| full`, `| ok`, and `| violated <field>` (inserted/removed lifecycle is pinned at 690_016)
- `KORU161` std/store:insert({s}): column '{s}' is not a leaf of kind '{s}' — {s} holds {s}
- `KORU161` std/store:insert({s}): column '{s}' is owned - its value must be an instance the caller gives up (single ownership, 690_053); a row projection is a borrow the source store still owns, and accepting it would put one pointer under two teardowns. Take or build a fresh instance for this row instead.
- `KORU161` std/store:insert({s}): column '{s}' is owned by another kind and cannot be zero-filled — name it only on the kind that holds it
- `KORU161` std/store:insert({s}): kind: '{s}' names no members — store '{s}' declares no union members (a kind needs members: player: Player, ...)
- `KORU161` std/store:insert({s}): row block is missing column '{s}'
- `KORU161` std/store:insert({s}): string literal ({d} bytes) overflows char[{d}] column '{s}' - a fixed-char column holds at most its declared byte length
- `KORU161` std/store:insert({s}): this store holds kinds ({s}) — name one: insert({s}, kind: {s})
- `KORU161` std/store:insert({s}): unknown kind '{s}' — members are {s}
- `KORU161` std/store:insert({s}): {s}
- `KORU161` std/store:insert: unknown store '{s}' - no std/store:new({s}) found

## `std/store:new` (81 refusals — fired 28× in the corpus)
- `KORU161` std/store:new requires a name and a seed block: create(name) {{ field: value[type] }}
- `KORU161` std/store:new({s}): [entity(...)] with an owned-string column - one obligation surface per store this rung (the row's <taken!> and the field's <instance!> compose at a later rung)
- `KORU161` std/store:new({s}): [tree] needs a container store - declare a capacity (`capacity: N`, N > 1); a capacity-1 value has no rows to arrange
- `KORU161` std/store:new({s}): [tree] synthesizes the `parent` column itself (TT1, invisible) - drop the explicit `parent` declaration
- `KORU161` std/store:new({s}): [tree] with an owned-string column is a later rung
- `KORU161` std/store:new({s}): `! cleared` binds '{s}' but never uses it — discard it (`! cleared _`) or use the count in the body
- `KORU161` std/store:new({s}): `! cleared` binds the COUNT of rows removed, not a payload block - write `! cleared <name>` (or `! cleared _` to discard). Row fields ride `inserted`/`removed`; after a clear there is no row to read
- `KORU161` std/store:new({s}): `! discharge` applies only to a store with a column the store cannot discharge unattended - every owned column here has one, so they auto-discharge at teardown and the arm would never fire
- `KORU161` std/store:new({s}): `! discharge` binds the column itself - spell it `! discharge item |> ...(<param>: item)`
- `KORU161` std/store:new({s}): `! discharge` binds the whole row record - spell it `! discharge item |> ...(item.<field>)`
- `KORU161` std/store:new({s}): `! step` binds '{s}' but never steps it - the body is the step call (`|> <module>:<step>({s})`)
- `KORU161` std/store:new({s}): `! step` binds the row itself - spell it `! step s |> <module>:<step>(s)`
- `KORU161` std/store:new({s}): `! step` cannot see the step tor's contract - the callee's `|` verdicts are the store's vocabulary, so its declaration must be in scope
- `KORU161` std/store:new({s}): `! step` this rung lives on a one-owned-column store - the row IS its obligation, which is what lets `| complete` retire it; rows of several columns step later
- `KORU161` std/store:new({s}): `! step`'s callee carries a value on `| {s}` - verdicts are words the store reads, not payloads; a payload-carrying verdict is a later slice
- `KORU161` std/store:new({s}): `! step`'s callee never answers `| complete` - a participant with no way out can never retire, so a pump over it drains nothing
- `KORU161` std/store:new({s}): `! updated {{ old, new }}` carries ONE written-field image type, but this store mixes column types - per-field updated deltas are a later rung; the discard form (`! updated _`) stays legal
- `KORU161` std/store:new({s}): `! updated` binds the written field's images — destructure exactly {{ old, new }} (row fields ride `inserted`/`removed`)
- `KORU161` std/store:new({s}): `! updated` must destructure exactly {{ old, new }} this slice
- `KORU161` std/store:new({s}): `! wait` binds '{s}' but never asks it - the body is the interest call (`|> <module>:<interest>({s})`)
- `KORU161` std/store:new({s}): `! wait` binds the row itself - spell it `! wait s |> <module>:<interest>(s)`
- `KORU161` std/store:new({s}): `! wait` cannot see the interest tor's contract - its `-> i32`/`i128`/`{{ fd, wait_ns }}` return must be in scope
- `KORU161` std/store:new({s}): `! wait` is a native-runtime contract this rung - the pump's union wait polls OS descriptors, which a browser loop cannot block on
- `KORU161` std/store:new({s}): `! wait` this rung lives on a one-owned-column store - the row IS its obligation; rows of several columns declare interests later
- `KORU161` std/store:new({s}): `! wait`'s callee returns `{s}` - the interest contract is `-> i32` (fd), `-> i128` (re-poll ns), or `-> {{ fd: i32, wait_ns: i128 }}` (both)
- `KORU161` std/store:new({s}): `! wait`'s callee returns nothing - the interest contract is `-> i32` (fd), `-> i128` (re-poll ns), or `-> {{ fd: i32, wait_ns: i128 }}` (both)
- `KORU161` std/store:new({s}): `! {s}` binds '{s}' but never uses it — discard the payload (`! {s} _`), or use the field in the body
- `KORU161` std/store:new({s}): `! {s}` payload field '{s}' is not a field of store '{s}' - the payload puns COLUMNS; to name what the site synthesizes, annotate it (`[id]{s}` is this row's handle)
- `KORU161` std/store:new({s}): `! {s}` projects row fields by pun (`{{ {s} }}`); renames are a later slice
- `KORU161` std/store:new({s}): `! {s}` requests `[id]{s}` but never uses it — a request is synthesized only where it is named, so drop it
- `KORU161` std/store:new({s}): `[id]{s}` takes the name of column '{s}' - the column and the row's handle are two values and need two names, and a reader cannot tell which '{s}' the body means
- `KORU161` std/store:new({s}): `[ordinal]{s}` on a `! {s}` arm - a lifecycle arm fires on ONE row's birth or death and has no traversal, so there is no position in a walk to name (this is not unimplemented; it is meaningless here). `[ordinal]` is a sweep request: `! query {{ [row]r, [ordinal]n }}`
- `KORU161` std/store:new({s}): `[row]{s}` on a `! {s}` arm - the arm already IS about one row and puns its columns by name (`! {s} {{ {s} }}`); binding the row to address OTHER columns is not built this rung. `[id]` is, and names this row's handle
- `KORU161` std/store:new({s}): `| {s}` on the step call is the store's verdict, not the arm's - `| complete` retires the row and every other verdict keeps it for the next pass; the arm carries `!` effects only
- `KORU161` std/store:new({s}): `| {s}` under `! wait` has nothing to answer - the interest call RETURNS the interest (`i32`/`i128`/`{{ fd, wait_ns }}`), it does not branch; the arm carries `!` effects only
- `KORU161` std/store:new({s}): a guarded watch on a field that also has interceptors or sibling watches is a later slice
- `KORU161` std/store:new({s}): an owned column of *{s}:{s} needs module {s} in scope - add `import {s}`
- `KORU161` std/store:new({s}): capacity above 16777215 is a later rung - the row handle carries the slot in 24 bits (store brand in bits 24..31, 690_196)
- `KORU161` std/store:new({s}): capacity must be >= 1 (capacity 1 is the reactive value shape; capacity > 1 is the container shape)
- `KORU161` std/store:new({s}): capacity must be an integer literal (got '{s}')
- `KORU161` std/store:new({s}): column '{s}' packs a proto member — dotted columns have no JS lowering yet (an access spells `store.web.port`, a nested-property misread); flatten the member to leaf columns or target zig
- `KORU161` std/store:new({s}): field '{s}' is an owned column - owned columns live on the container shape (declare `capacity: N`, N > 1); the capacity-1 value tier is scalar-only this rung
- `KORU161` std/store:new({s}): field '{s}' is char[{d}] - fixed-char columns live on the container shape (declare `capacity: N`, N > 1); the capacity-1 value tier is scalar-only this rung
- `KORU161` std/store:new({s}): field '{s}' is ref({s}) but no store holds {s} rows — a ref column needs a home: a container store whose row carries the target's fields (std/store:new(dogs, capacity: N) {{ Dog }}); without one the column can only ever hold -1
- `KORU161` std/store:new({s}): field '{s}' is {s} - an owned column must be a well-formed `*mod:Type<state!>` (pointer, module-qualified type, held obligation)
- `KORU161` std/store:new({s}): field '{s}' is {s} - an owned column must hold a live obligation `<state!>` (a bare `<state>` borrow is not owned; 330_067/069)
- `KORU161` std/store:new({s}): field '{s}' is {s} - an owned column type must be module-qualified `*mod:Type<state!>` so the store can locate its discharger
- `KORU161` std/store:new({s}): field '{s}' is {s} — columns are scalars (i64/i32/f64/f32), fixed-char (char[N], 690_052), owned strings (*std/string:String<std/string:instance!>, 690_053), or ref() row handles (698_009); vec/mat tiers are pinned at 690_020
- `KORU161` std/store:new({s}): field '{s}' names unknown ref target '{s}' — ref() takes a declared compound of its home, or a qualified name from another home
- `KORU161` std/store:new({s}): field '{s}': char[N] needs N >= 1 - a zero-length fixed-char column holds nothing
- `KORU161` std/store:new({s}): field '{s}': char[N] needs an integer byte length (got '{s}')
- `KORU161` std/store:new({s}): field interceptor `! {s}` must discard its payload (`! {s} _`) this slice - bind values via `updated {{ old, new }}`
- `KORU161` std/store:new({s}): fixed-char (char[N]) and owned-string columns in one store are a later rung
- `KORU161` std/store:new({s}): guarded interceptors are a later slice - interceptors are the store's unconditional contract
- `KORU161` std/store:new({s}): interceptor branch '{s}' is neither a field nor `updated` (inserted/removed are rung two)
- `KORU161` std/store:new({s}): kinds need a container store - declare a capacity (`capacity: N`, N > 1); a capacity-1 value has no rows to tag
- `KORU161` std/store:new({s}): leaf '{s}' names unknown '{s}' — a leaf must be a scalar material or a terminal of its home
- `KORU161` std/store:new({s}): member '{s}' carries a default — members expand to columns, they hold no value
- `KORU161` std/store:new({s}): member '{s}' declares no fields — a proto must name at least one leaf
- `KORU161` std/store:new({s}): mixed column types in one store are a later slice - all fields must share one scalar type for now
- `KORU161` std/store:new({s}): mixing `updated {{ old, new }}` with field watches/interceptors on one store is a later slice
- `KORU161` std/store:new({s}): mixing a canonical owned column (*{s}:{s}) with an ambiguous one (*{s}:{s}) in one store is a later rung - the drain's `! discharge` payload and auto-discharge compose there
- `KORU161` std/store:new({s}): more than 255 stores in one program is a later rung - the row handle carries the minting store's brand in 8 bits, and brand 0 is reserved so a non-handle integer cannot pass as an address (690_196)
- `KORU161` std/store:new({s}): one `! discharge` handler per store - the teardown fires ONE handler per live element
- `KORU161` std/store:new({s}): one `! step` handler per store - a pass steps each row once
- `KORU161` std/store:new({s}): one `! wait` handler per store - a pass asks each row for its interest once
- `KORU161` std/store:new({s}): plural interceptor branch '{s}' - the lifecycle slice wires `inserted`, `removed`, `updated` and `cleared`; field interceptors on plural rows are a later slice
- `KORU161` std/store:new({s}): seed block has no fields
- `KORU161` std/store:new({s}): the `! discharge` handler needs a body that discharges the row's obligation (e.g. `! discharge item |> {s}:commit(tx: item)`)
- `KORU161` std/store:new({s}): the `! discharge` handler needs a body that discharges the row's obligations (e.g. `! discharge item |> {s}:commit(item.<field>)`)
- `KORU161` std/store:new({s}): the `! step` body starts with the step call this rung
- `KORU161` std/store:new({s}): the `! step` handler needs a body - the step call itself (`|> <module>:<step>({s})`)
- `KORU161` std/store:new({s}): the `! updated` interceptor body must start with an invocation this rung
- `KORU161` std/store:new({s}): the `! updated` interceptor needs a body (`|> std/store:stored {{ ... }}`)
- `KORU161` std/store:new({s}): the `! wait` body starts with the interest call this rung
- `KORU161` std/store:new({s}): the `! wait` handler needs a body - the interest call itself (`|> <module>:<interest>({s})`) returning `i32` (fd), `i128` (re-poll ns), or `{{ fd, wait_ns }}`
- `KORU161` std/store:new({s}): the `! {s}` interceptor body must start with an invocation this rung
- `KORU161` std/store:new({s}): the `! {s}` interceptor needs a body (`|> std/store:stored {{ ... }}`)
- `KORU161` std/store:new({s}): the `updated` interceptor over an owned column is a later rung - it carries TWO owned images (old and new) of the written field; `inserted`/`removed`/`watch` over owned are built (690_061/065/063)
- `KORU161` std/store:new({s}): unknown request `[{s}]` on '{s}' - a `! {s}` arm understands [id]
- `KORU161` std/store:new({s}): {s}

## `std/supervisor:supervised` (47 refusals — fired 25× in the corpus)
- `KORU161` std/supervisor:supervised must sit on a branch arm of an event call
- `KORU161` std/supervisor:supervised must sit on a branch arm of the call it supervises
- `KORU161` std/supervisor:supervised requires a policy — arm children (`| retry t when t < N`), a block (`supervised {{ restart: N }}`), or delegation (`supervised {{ policy: name }}`)
- `KORU161` std/supervisor:supervised: 'policy' declared twice — one delegated policy per supervised call
- `KORU161` std/supervisor:supervised: 'policy:' delegates the decisions — 'restart:'/'args:' spell them inline; keep one rule-source per supervised call
- `KORU161` std/supervisor:supervised: 'restart:'/'args:'/'policy:' fields and `| retry`/`| exhausted` arms spell the same decisions — keep rules in one place (a 'within:' declaration composes with either)
- `KORU161` std/supervisor:supervised: 'within' declared twice — one spacing bound per policy
- `KORU161` std/supervisor:supervised: 'within' modifies a policy — with no 'restart:'/'policy:' field and no `| retry` arms there is nothing to space
- `KORU161` std/supervisor:supervised: '{s}' declares '| {s}' with a payload — '{s}'s '| {s}' is void and carries nothing to forward
- `KORU161` std/supervisor:supervised: '{s}' declares a '__more' branch — the fold's loop arm needs the name
- `KORU161` std/supervisor:supervised: '{s}' declares no branch '| {s}'
- `KORU161` std/supervisor:supervised: '{s}' input '__last' collides with the within-spacing field
- `KORU161` std/supervisor:supervised: '{s}' lives in '{s}' — v1 supervises same-module children only
- `KORU161` std/supervisor:supervised: '| [{s}]' declares nothing on an outcome arm — policy declarations ride the block: 'supervised {{ {s} }}'
- `KORU161` std/supervisor:supervised: '| {s} {s}' binds nothing — '{s}' declares '| {s}' with no payload
- `KORU161` std/supervisor:supervised: '| {s} {{…}}' destructures nothing the fold reads — bind the failure payload by name ('| {s} f |>')
- `KORU161` std/supervisor:supervised: '| {s} {{…}}' destructures nothing — '{s}' declares '| {s}' with no payload
- `KORU161` std/supervisor:supervised: '| {s}' carries no payload — write `=> {s}`
- `KORU161` std/supervisor:supervised: '| {s}' is claimed by more than one arm — supervise exactly one
- `KORU161` std/supervisor:supervised: `=> {s}` carries a payload — `=> {s} <expr>`
- `KORU161` std/supervisor:supervised: `| exhausted => {s}` — '{s}' declares no branch '{s}'
- `KORU161` std/supervisor:supervised: `| exhausted` binds nothing — the failure payload rides under the arm's own binding ('{s}')
- `KORU161` std/supervisor:supervised: `| exhausted` produces the terminal outcome: `=> {s} {s}` — or write no `| exhausted` at all for forward-in-kind
- `KORU161` std/supervisor:supervised: `| retry` needs a `when` — an unconditional retry never terminates. Bound it on the attempt counter: `| retry t when t < N`
- `KORU161` std/supervisor:supervised: `| retry` re-enters through a `|>` call — a `=>` produce is terminal and belongs on `| exhausted`
- `KORU161` std/supervisor:supervised: a policy needs at least one `| retry` arm — `| exhausted` alone is the plain arm spelling
- `KORU161` std/supervisor:supervised: an unconditional `| exhausted` is terminal — it must be the last policy arm
- `KORU161` std/supervisor:supervised: args names '{s}' — '{s}' has no input field '{s}'
- `KORU161` std/supervisor:supervised: args references '{s}' — '| {s}' carries no failure payload
- `KORU161` std/supervisor:supervised: args: {s}
- `KORU161` std/supervisor:supervised: counter '{s}' collides with a '{s}' input field — pick another name
- `KORU161` std/supervisor:supervised: counter binding '{s}' collides with the failure payload binding — pick another
- `KORU161` std/supervisor:supervised: counter binding '{s}' — generated names live under '__', pick another
- `KORU161` std/supervisor:supervised: failure binding '{s}' collides with a '{s}' input field — pick another
- `KORU161` std/supervisor:supervised: no `| retry` arm bounds on the attempt counter — keep-alive conditions must carry their own escape: `| retry t when t < N`
- `KORU161` std/supervisor:supervised: no event declaration found for '{s}'
- `KORU161` std/supervisor:supervised: policy arms are `| retry` and `| exhausted` — got '| {s}'
- `KORU161` std/supervisor:supervised: policy block must declare 'restart: N'
- `KORU161` std/supervisor:supervised: re-entry argument references '{s}' — '| {s}' carries no failure payload
- `KORU161` std/supervisor:supervised: re-entry calls '{s}' only — '{s}' returns a different outcome vocabulary (cross-event re-entry lands with the union work)
- `KORU161` std/supervisor:supervised: re-entry names '{s}' — '{s}' has no input field '{s}' (label the argument: `{s}: …`)
- `KORU161` std/supervisor:supervised: restart must be a non-negative integer literal, got '{s}'
- `KORU161` std/supervisor:supervised: restart must be at least 1 — 'restart: 0' declares no retries; the plain '| {s} f => {s} f' arm already spells forward-as-is
- `KORU161` std/supervisor:supervised: retry arms share one counter — got '| retry {s}' and '| retry {s}'
- `KORU161` std/supervisor:supervised: retry condition references '{s}' — '| {s}' carries no failure payload
- `KORU161` std/supervisor:supervised: unknown policy field '{s}' — rule fields: restart, args, policy; modifier: within
- `KORU161` std/supervisor:supervised: {s}

## `std/refine` (19 refusals — fired 10× in the corpus)
- `KORU205` std/refine({s}): '{s}' is not an alternative — a disjunction lists integer literals, at most one of them marked `*` (e.g. `*1 | 2 | 3`)
- `KORU205` std/refine({s}): '{s}' lists no alternatives
- `KORU205` std/refine({s}): '{s}' marks two defaults — `*` selects ONE fallback value
- `KORU205` std/refine({s}): '{s}' needs two bounds — the spelling is `clamp(lo, hi)`
- `KORU205` std/refine({s}): an entry with no fields refines nothing — declare at least one `name: type` field
- `KORU205` std/refine({s}): bound '{s}' needs an integer literal — '{s}' does not parse
- `KORU205` std/refine({s}): clamp bound '{s}' needs an integer literal
- `KORU205` std/refine({s}): clamp({d}, {d}) is empty — lo exceeds hi
- `KORU205` std/refine({s}): constraint atom '{s}' is not a bound — refine understands >N >=N <N <=N ==N over integer literals
- `KORU205` std/refine({s}): field '{s}' constrains base '{s}' — bounds and clamps refine integer scalars only
- `KORU205` std/refine({s}): field '{s}' declared with base '{s}' but already met as '{s}' — a meet needs one base, not two
- `KORU205` std/refine({s}): field '{s}' declares base '{s}' but the declaration says '{s}' — a meet needs one base, not two
- `KORU205` std/refine({s}): field '{s}' refines to nothing — '{s}' and '{s}' cannot both hold
- `KORU205` std/refine({s}): field '{s}' refines to nothing — '{s}' contradicts '{s}'
- `KORU205` std/refine({s}): field line '{s}' has no ':' — each field must be `name: type [& constraint…]`
- `KORU205` std/refine({s}): field line '{s}' is missing a name or a type
- `KORU205` std/refine({s}): names no field '{s}' — the declaration has none to refine
- `KORU205` std/refine({s}): no declaration named '{s}' in home '{s}' to refine — refine meets a `std/proto` declaration
- `KORU205` std/refine: the entry name '{s}' is not usable — a refine name must be a non-empty identifier or a qualified `home:Name`

## `std/io:print` (1 refusals — fired 7× in the corpus)
- `KORU168` std/io:print.blk: '{{{{ {s} }}}}' uses keyed addressing 'store[key: value]' - a pinned hole (690_018); bind the row's handle and interpolate store[handle].field instead

## `std/proto` (7 refusals — fired 5× in the corpus)
- `KORU173` std/proto({s}): an entry with no fields derives nothing — declare at least one `name: type` field or a `<:` parent
- `KORU173` std/proto({s}): compound cycle detected: {s} — a compound graph must be acyclic; expansion would never terminate
- `KORU173` std/proto({s}): field '{s}' names unknown ref target '{s}' — ref() takes a declared compound of its home, or a qualified name from another home
- `KORU173` std/proto({s}): field '{s}' names unknown terminal '{s}' — a field must use a scalar material, a terminal or compound of its own home, or a qualified name from another home
- `KORU173` std/proto({s}): {s}
- `KORU173` std/proto: '{s}: {s}' reads as a labeled argument — extension is spelled `Name <: Parent` (field-set union), e.g. std/proto(Dog <: Animal)
- `KORU173` std/proto: the entry name '{s}' is not usable — a proto name must be an identifier (a-z, A-Z, 0-9, '_', '-'; no leading digit)

## `std/indexes:store` (2 refusals — fired 3× in the corpus)
- `KORU161` std/indexes:store({s}, {s}): no column named '{s}' - the index names a declared column of the store
- `KORU161` std/indexes:store({s}, {s}): the indexed column must be a scalar column - fixed-char and owned columns are a later rung

## `std/channel:new` (28 refusals — fired 2× in the corpus)
- `KORU161` std/channel:new needs the channel name — `std/channel:new(inbox, capacity: N) {{ kind: Proto }}`
- `KORU161` std/channel:new({s}): '{s}' is a bare positional — capacity is named: `capacity: N`
- `KORU161` std/channel:new({s}): '{s}' is not usable as an arm word — it must be an identifier
- `KORU161` std/channel:new({s}): '{s}' names no proto entry — the payload type is a registry name (std/proto({s}) {{ ... }})
- `KORU161` std/channel:new({s}): `! {s}` attaches at the join, not the declaration — `std/channel({s}) ! {s} v |> ...` collects consumers program-wide
- `KORU161` std/channel:new({s}): `closed` is channel state, not a message kind — the `! closed` arm is the close transition; pick another word
- `KORU161` std/channel:new({s}): `| {s}` doesn't parse on a declaration — the declaration takes only the branch-table body; consumers are `!` arms on `std/channel({s})`
- `KORU161` std/channel:new({s}): a channel declares its vocabulary — `std/channel:new({s}, capacity: {d}) {{ reading: Reading }}`
- `KORU161` std/channel:new({s}): a channel is sized at the declaration — `capacity: N`, a power of two above zero
- `KORU161` std/channel:new({s}): a channel named '{s}' already exists — one declaration per name
- `KORU161` std/channel:new({s}): capacity '{s}' is not a comptime integer — the ring is sized at the declaration
- `KORU161` std/channel:new({s}): capacity 0 is rendezvous — a send whose ok fires on the consumer's take — and that spelling is deferred (docs/CHANNEL.md). Buffered channels take a power of two above zero
- `KORU161` std/channel:new({s}): capacity {d} is not a power of two — the Vyukov ring masks by cap-1
- `KORU161` std/channel:new({s}): each entry is `kind: Proto` — the arm word and the payload type it carries
- `KORU161` std/channel:new({s}): join arm `! closed` binds nothing — the arm fires on the close transition, there is no value to name
- `KORU161` std/channel:new({s}): join arm `! closed` needs a body (`|> <call>`)
- `KORU161` std/channel:new({s}): join arm `! closed` needs a call body — it runs at the close transition
- `KORU161` std/channel:new({s}): join arm `! {s} {s}` needs a body (`|> <call>({s})`)
- `KORU161` std/channel:new({s}): join arm `! {s}` binds the message — spell it `! {s} v |> <body>`
- `KORU161` std/channel:new({s}): join arm `! {s}` names no kind — {s} carries {s} (and `closed`)
- `KORU161` std/channel:new({s}): join arm `! {s}` needs a call body — it runs at the delivery point, where a bare `.branch` has no flow to answer
- `KORU161` std/channel:new({s}): kind '{s}' is declared twice — the vocabulary takes each name once
- `KORU161` std/channel:new({s}): kind '{s}' transits two obligation states ('{s}' and '{s}') — a consumer arm mints one phantom per kind; split the channel or the states
- `KORU161` std/channel:new({s}): the branch table is empty — a channel needs at least one message kind (`{{ reading: Reading }}`)
- `KORU161` std/channel:new({s}): {s}
- `KORU161` std/channel:new: a channel declaration is a top-level item
- `KORU161` std/channel:new: the channel name '{s}' is not usable — it must be an identifier (a-z, A-Z, 0-9, '_', '-'; no leading digit)
- `KORU161` std/channel:new: unknown argument '{s}' — the head is `std/channel:new(name, capacity: N) {{ kind: Proto }}`

## `std/list:new` (2 refusals — fired 2× in the corpus)
- `KORU173` std/list:new({s}): container synthesis produced no units — the proto entry was not found or has no parseable fields
- `KORU173` std/list:new({s}): field '{s}' is ref({s}) but no store holds {s} rows — a ref field needs a home: a plural store whose row carries the target's fields (std/store:new(dogs, capacity: N) {{ Dog }}); without one the field can only ever hold -1

## `std/channel:close` (1 refusals — fired 1× in the corpus)
- `KORU161` std/channel:close({s}) takes no value — `close({s}) | ok |> ...`

## `std/channel:send` (3 refusals — fired 1× in the corpus)
- `KORU161` std/channel:send({s}) needs the value — `send({s}, {s}: reading)`
- `KORU161` std/channel:send({s}): a multi-kind channel can't infer the kind — name it: `send({s}, {s}: v)`
- `KORU161` std/channel:send({s}): one message per send — the bare value and `{s}: …` both name one

## `std/rings:new` (21 refusals — fired 1× in the corpus)
- `KORU161` std/rings:new needs the ring name — `std/rings:new(feed, capacity: N) {{ value: Type }}`
- `KORU161` std/rings:new({s}): '{s}' is a bare positional — capacity is named: `capacity: N`
- `KORU161` std/rings:new({s}): '{s}' is not usable as the element word — it must be an identifier
- `KORU161` std/rings:new({s}): '{s}' names no proto and no scalar — declare it `std/proto({s}) {{ ... }}` or use a scalar
- `KORU161` std/rings:new({s}): `| {s}` doesn't parse on a declaration — the declaration takes only the element body
- `KORU161` std/rings:new({s}): a ring carries plain values — '{s}' is a borrow, array, or phantom-typed element, and none of those have a slot shape this rung
- `KORU161` std/rings:new({s}): a ring declares its element — `std/rings:new({s}, capacity: {d}) {{ value: Type }}`
- `KORU161` std/rings:new({s}): a ring has no `!` arms — competing consumers over a named buffer are `std/channel:new({s}, capacity: N) {{ kind: Proto }}`
- `KORU161` std/rings:new({s}): a ring holds ONE element shape — more than one named lane is a channel: `std/channel:new({s}, capacity: {d}) {{ kind: Proto }}`
- `KORU161` std/rings:new({s}): a ring is buffered storage — capacity is a power of two above zero (direct handoff is `std/channel`'s deferred rendezvous)
- `KORU161` std/rings:new({s}): a ring is sized at the declaration — `capacity: N`, a power of two above zero
- `KORU161` std/rings:new({s}): a ring named '{s}' already exists — one declaration per name
- `KORU161` std/rings:new({s}): capacity '{s}' is not a comptime integer — the ring is sized at the declaration
- `KORU161` std/rings:new({s}): capacity {d} is not a power of two — the Vyukov ring masks by cap-1
- `KORU161` std/rings:new({s}): name the element — `{{ value: {s} }}` — the word labels it in diagnostics and generated units
- `KORU161` std/rings:new({s}): the element body is empty — a ring declares what it holds (`{{ value: u64 }}`)
- `KORU161` std/rings:new({s}): the element needs a type — `{{ {s}: Type }}`
- `KORU161` std/rings:new({s}): {s}
- `KORU161` std/rings:new: a ring declaration is a top-level item
- `KORU161` std/rings:new: the ring name '{s}' is not usable — it must be an identifier (a-z, A-Z, 0-9, '_', '-'; no leading digit)
- `KORU161` std/rings:new: unknown argument '{s}' — the head is `std/rings:new(name, capacity: N) {{ value: Type }}`

## `std/store:rule` (11 refusals — fired 1× in the corpus)
- `KORU161` std/store:rule requires a store name: query(name)
- `KORU161` std/store:rule({s}) is top-level-only: it cannot be nested inside a handler or loop body. `query` is a standing-rule installation (comptime-fused into the store's write paths), so a nested body has nothing to install into. The store IS declared - move the query to module (top-level) scope. Momentary verbs (insert/take) DO run in nested bodies.
- `KORU161` std/store:rule({s}): [name(...)] takes exactly one identifier — [name(movement)]
- `KORU161` std/store:rule({s}): depends_on cycle among rules: {s}
- `KORU161` std/store:rule({s}): depends_on({s}) — bare rule names resolve in the declaring module only; rule '{s}' lives in module '{s}', write depends_on({s}:{s})
- `KORU161` std/store:rule({s}): depends_on({s}) — no rule named [name({s})] on this store in module '{s}'
- `KORU161` std/store:rule({s}): the query body must start with an invocation this rung
- `KORU161` std/store:rule({s}): the query branch needs a body (`|> ...`)
- `KORU161` std/store:rule({s}): the query precedes its store's create in source - declare the store first
- `KORU161` std/store:rule({s}): two rules named [name({s})] in module '{s}' — rule names are unique per module
- `KORU161` std/store:rule({s}): unknown store - no std/store:new({s}) found (or the store is a capacity-1 value - queries need a container, declare `capacity: N` at create)

## `std/store:take` (4 refusals — fired 1× in the corpus)
- `KORU161` std/store:take addresses a row: take(store[handle]) - '{s}' has no addressing head
- `KORU161` std/store:take({s}[...]): unknown or not-yet-created container store '{s}'
- `KORU161` std/store:take: malformed addressing head '{s}'
- `KORU161` std/store:take: malformed addressing head '{s}' - take(store[handle])

## `std/types` (3 refusals — fired 1× in the corpus)
- `KORU173` std/types/proto({s}): an entry with no fields derives nothing — declare at least one `name: type` field
- `KORU173` std/types/proto({s}): field '{s}' uses unsupported type '{s}' — scalar fields only this rung (i8/i16/i32/i64/u8/u16/u32/u64/f32/f64/bool/string)
- `KORU173` std/types/proto({s}): {s}

## `(unprefixed)` (28 refusals — fired 0× in the corpus)
- `KORU161` ?
- `KORU171` `{s}` is bound but not pinned — vendor.lock has no entry for it. Re-pin with `koruc {s} vendor sync`
- `KORU171` no vendor.lock — vendored source is unpinned, so nothing can detect a change to it. Pin it with `koruc {s} vendor sync`
- `KORU162` regex match: destructure field '{s}' carries annotation '[{s}]' — a match delivers named groups only; honored or refused, never silently ignored
- `KORU162` regex match: destructure field '{s}' has no named group in pattern `{s}`
- `KORU162` regex match: named group '{s}' has no destructure field — take delivery, or make it non-capturing: spell it (...)
- `KORU162` regex match: nested destructure has no meaning for a text span (field '{s}')
- `KORU162` regex match: pattern `{s}` declares named groups but the branch discards the payload — destructure them, bind the payload, or make the unwanted capture non-capturing: spell it (...)
- `KORU162` regex scan: destructure field '{s}' carries annotation '[{s}]' — a scan delivers named groups only; honored or refused, never silently ignored
- `KORU162` regex scan: destructure field '{s}' has no named group in pattern `{s}`
- `KORU162` regex scan: named group '{s}' has no destructure field — take delivery, or make it non-capturing: spell it (...)
- `KORU162` regex scan: nested destructure has no meaning for a text span (field '{s}')
- `KORU162` regex scan: pattern `{s}` declares named groups but the branch discards the payload — destructure them, bind the payload, or make the unwanted capture non-capturing: spell it (...)
- `KORU162` regex: cannot compile pattern `{s}`: {s}
- `KORU165` trellis \\"{s}\\" is not defined - expected ~std/trellis:define(\\"{s}\\") with pattern arms
- `KORU171` vendor.lock is unreadable ({s}) — delete it and re-pin with `vendor sync`
- `KORU171` vendored `{s}` does not match its pin (tree hash differs but no file did — the lock is corrupt). Re-pin with `koruc {s} vendor sync`
- `KORU171` vendored `{s}` drifted from its pin: {s} `{s}` and {d} more. Review it with `koruc {s} vendor diff`, then re-pin with `vendor sync` once you have read the change
- `KORU171` vendored `{s}` drifted from its pin: {s} `{s}`. Review it with `koruc {s} vendor diff`, then re-pin with `vendor sync` once you have read the change
- `KORU171` vendored tree for `{s}` cannot be read at `{s}` ({s})
- `KORU164` {s}
- `KORU163` {s}
- `KORU173` {s}
- `KORU161` {s}
- `KORU161` {s}: keyed addressing '{s}' is a pinned hole (690_018) - no key->row map is emitted; address the row by handle instead (store[handle])
- `KORU164` ~capture requires a `! as <cell>` effect branch
- `KORU164` ~capture requires a seed block: capture {{ field: value }}
- `KORU164` ~capture seed: {s}

## `std/channel` (15 refusals — fired 0× in the corpus)
- `KORU161` std/channel(name): the join needs the channel name
- `KORU161` std/channel({s}): `| {s}` doesn't parse on the join — consumers are `! <kind> <bind> |> ...` arms; the chain steps (`std/channel:send/recv/close`) carry the `|` branches
- `KORU161` std/channel({s}): the consumer join is a top-level item — attach it beside the declaration, not inside a flow
- `KORU161` std/channel({s}): the join precedes its channel's declaration in source — declare the channel first (rung-one ordering)
- `KORU161` std/channel({s}): the join takes only the name — vocabulary and capacity live on `std/channel:new`
- `KORU161` std/channel({s}): unknown channel — no std/channel:new({s}) found
- `KORU161` std/channel: channels are a native-runtime construct this rung — the Vyukov ring and its atomics have no JS lowering yet
- `KORU161` std/channel: consumer body references '{s}', runtime state of the enclosing flow — a `!` arm executes at '{s}'s delivery points, not here; bind it through a store or send on a channel
- `KORU161` std/channel: the bare reference is the consumer join — it is a top-level item, not a mid-chain step; consumers attach as `std/channel(name) ! <kind> v |> ...`
- `KORU161` std/channel:{s} needs the channel name — `std/channel:{s}(<name>)`
- `KORU161` std/channel:{s}({s}): '{s}' is declared BELOW this step — a channel's declaration precedes its uses in document order
- `KORU161` std/channel:{s}({s}): '{s}' names no kind — {s} carries {s}
- `KORU161` std/channel:{s}({s}): one message per send — '{s}' is a second kind label
- `KORU161` std/channel:{s}({s}): the declaration ran but its vocabulary marker is unreadable — internal gap, please report
- `KORU161` std/channel:{s}: no channel named '{s}' — `std/channel:new({s}, capacity: N) {{ kind: Proto }}` declares it

## `std/channel:consume` (2 refusals — fired 0× in the corpus)
- `KORU161` std/channel:consume requires a channel name: consume(name)
- `KORU161` std/channel:consume: a {{ }} block has no meaning on the join — the vocabulary lives on `std/channel:new`

## `std/channel:recv` (2 refusals — fired 0× in the corpus)
- `KORU161` std/channel:recv({s}) takes no value — `recv({s}) | some v |> ...`
- `KORU161` std/channel:recv({s}): recv can't spell one payload type on a multi-kind channel — consume by `!` arms: `std/channel({s}) ! {s} v |> ...`

## `std/constructor` (2 refusals — fired 0× in the corpus)
- `KORU166` std/constructor requires a `! construct` traversal branch
- `KORU166` std/constructor requires a name: std/constructor(nums)

## `std/constructor:struct` (1 refusals — fired 0× in the corpus)
- `KORU166` std/constructor:struct requires a `! construct` branch

## `std/foreign:struct` (4 refusals — fired 0× in the corpus)
- `KORU173` std/foreign:struct — the entry name '{s}' is not usable — a foreign name must be an identifier (a-z, A-Z, 0-9, '_', '-'; no leading digit)
- `KORU173` std/foreign:struct({s}): an entry with no fields registers nothing — declare at least one field name
- `KORU173` std/foreign:struct({s}): field '{s}' is not usable — a foreign field must be an identifier
- `KORU173` std/foreign:struct({s}): field line '{s}' carries a type — foreign fields are bare names (presence claims); the host owns substance

## `std/grid:new` (19 refusals — fired 0× in the corpus)
- `KORU161` std/grid:new requires a name and a cell block: new(name, size: N) {{ field: default[type] }}
- `KORU161` std/grid:new({s}): `size:` and `dimensions:` are two spellings of the same thing - give one
- `KORU161` std/grid:new({s}): a grid needs `size: N` or `dimensions: RxC` - every cell exists from declaration, so the count is not a capacity to grow into
- `KORU161` std/grid:new({s}): a grid needs at least one cell
- `KORU161` std/grid:new({s}): a grid needs at least one column
- `KORU161` std/grid:new({s}): column '{s}' has a malformed type - `{s}: 0[i64]`
- `KORU161` std/grid:new({s}): column '{s}' needs a default and a type - `{s}: 0[i64]`. A grid has no insert, so every cell is live from declaration and must say what it starts as
- `KORU161` std/grid:new({s}): dimensions are `RxC` (got '{s}')
- `KORU161` std/grid:new({s}): dimensions are `RxC` with integer literals (got '{s}')
- `KORU161` std/grid:new({s}): malformed cell block
- `KORU161` std/grid:new({s}): size must be an integer literal (got '{s}')
- `KORU161` std/grid:new: `[layout(...)]` names exactly one layout (got {d}) - a grid offers `row` and `column`
- `KORU161` std/grid:new: `[layout]` must name the layout - write `[layout(row)]` or `[layout(column)]`. A bare `[layout]` says nothing about which one was wanted
- `KORU161` std/grid:new: `[unsafe(...)]` waives exactly one facet at a time (got {d}) - a grid offers `bounds`
- `KORU161` std/grid:new: `[unsafe]` must name what it waives - write `[unsafe(bounds)]`. A bare `[unsafe]` would widen silently the day this construct grows a second check
- `KORU161` std/grid:new: `{s}` is not a layout this grid offers - it has `row` (one record per cell, for scatter) and `column` (one array per field, the default, for sweeps). A layout it does not implement is refused rather than ignored, because a misspelling would silently keep the layout you were trying to change
- `KORU161` std/grid:new: a grid has no `{s}` check to waive - it offers `bounds` (the per-access index floor). A facet it does not implement is refused rather than ignored, because an annotation that waives nothing still reads as one that did
- `KORU161` std/grid:new: malformed annotation '[{s}]' - the form is `[layout(row)]`
- `KORU161` std/grid:new: malformed annotation '[{s}]' - the form is `[unsafe(bounds)]`

## `std/grid:stored` (5 refusals — fired 0× in the corpus)
- `KORU161` std/grid:stored requires a write block: stored {{ grid[index].field: expr }}
- `KORU161` std/grid:stored: '{s}' does not address a grid cell - the target is `<grid>[<index>].<field>`, and a store row is written with std/store:stored instead
- `KORU161` std/grid:stored: grid '{s}' has no column '{s}'
- `KORU161` std/grid:stored: no grid is declared in this program - declare one with `std/grid:new(name, size: N) {{ ... }}`
- `KORU161` std/grid:stored: {s}

## `std/grid:sweep` (7 refusals — fired 0× in the corpus)
- `KORU161` std/grid:sweep requires a grid name: sweep(name)
- `KORU161` std/grid:sweep({s}): exactly one `! sweep <cell>` branch per site
- `KORU161` std/grid:sweep({s}): no grid named '{s}' is declared in this program
- `KORU161` std/grid:sweep({s}): the cell branch is spelled `! sweep <cell>`
- `KORU161` std/grid:sweep({s}): the sweep arm needs a body (`|> ...`)
- `KORU161` std/grid:sweep({s}): the sweep arm needs a cell binding: `! sweep <cell> |> ...`
- `KORU161` std/grid:sweep({s}): the sweep body must start with an invocation this rung

## `std/parser` (1 refusals — fired 0× in the corpus)
- `KORU163` std/parser: rule `{s}` is left-recursive (it can call itself before consuming input) — rewrite right-recursively: put a consuming element (a terminal) first

## `std/parser:grammar` (3 refusals — fired 0× in the corpus)
- `KORU163` std/parser:grammar requires a name: grammar(<name>)
- `KORU163` std/parser:grammar rule `{s}` needs a cursor binding: `! {s} <cursor> |> std/parser:match(<cursor>)`
- `KORU163` std/parser:grammar rules are effect arms: `! <rule-name> <cursor> |> std/parser:match(<cursor>)`, found terminal `{s}`

## `std/parser:parse` (6 refusals — fired 0× in the corpus)
- `KORU163` std/parser:parse dispatches ONE top rule (plus optional parse-error); found a second branch `{s}`
- `KORU163` std/parser:parse needs a top-rule branch: `| <rule> <binding> |> ...`
- `KORU163` std/parser:parse needs its grammar named: parse(<input>, grammar: <name>)
- `KORU163` std/parser:parse requires an input: parse(<expression>, grammar: <name>)
- `KORU163` std/parser:parse: `{s}` is not a rule of grammar `{s}`
- `KORU163` std/parser:parse: no grammar named `{s}` in this program — declare it: std/parser:grammar({s}) with `! <rule> <cursor>` arms

## `std/regex:match` (1 refusals — fired 0× in the corpus)
- `KORU162` std/regex:match requires an input argument: match(<expression>)

## `std/regex:scan` (4 refusals — fired 0× in the corpus)
- `KORU162` std/regex:scan pattern `{s}` must be an effect branch `!` (it fires once per match), not a terminal `|`
- `KORU162` std/regex:scan requires a `!` pattern branch
- `KORU162` std/regex:scan requires an input argument: scan(<expression>)
- `KORU162` std/regex:scan supports a single pattern branch for now; multi-pattern scan (leftmost-across-patterns) is pinned as a follow-up

## `std/rings` (3 refusals — fired 0× in the corpus)
- `KORU161` std/rings: rings are a native-runtime construct this rung — the Vyukov ring and its atomics have no JS lowering yet
- `KORU161` std/rings:{s} takes the ring by name — `{s}(feed)`; the ring is declared `std/rings:new(feed, capacity: N) {{ value: Type }}`
- `KORU161` std/rings:{s}: no ring named '{s}' — declare it `std/rings:new({s}, capacity: N) {{ value: Type }}` above this use

## `std/rings:dequeue` (2 refusals — fired 0× in the corpus)
- `KORU161` std/rings:dequeue({s}) takes no value — `dequeue({s}) | some v |> ...`
- `KORU161` std/rings:dequeue({s}): '{s}:' isn't a ring argument — `dequeue({s})`

## `std/rings:enqueue` (2 refusals — fired 0× in the corpus)
- `KORU161` std/rings:enqueue({s}) needs the value — `enqueue({s}, v: x)`
- `KORU161` std/rings:enqueue({s}): '{s}:' isn't a ring argument — the value is `v:`-labeled: `enqueue({s}, v: x)`

## `std/store` (11 refusals — fired 0× in the corpus)
- `KORU161` std/store(name): the reference form needs a store name
- `KORU161` std/store({s}): only the reactive-attach form of the reference is built — `std/store({s}) ! <field> <bind> |> ...`. The operation form (`| store s |> ...`) is a later rung; for now operate by name (std/store:insert({s}), std/store:stored).
- `KORU161` std/store: watch body references '{s}', runtime state of the enclosing flow - a watch body executes at '{s}'s write sites, not here; bind it through a store or react at a write site
- `KORU161` std/store:{s}({s}): '{s}' is an unannotated entry - the {s} arm binds its row (`! {s} <row> |> ... <row>.<field> ...`); a request block names what the SITE synthesizes (`[row]`, `[id]`), never columns (the retired projection block is 690_089)
- `KORU161` std/store:{s}({s}): `[id]{s}` reuses the row's own name - the row and its handle are two values and need two names
- `KORU161` std/store:{s}({s}): `[ordinal]` on '{s}' - a {s} arm has a row and no traversal, so there is no position in a walk to name (this is not unimplemented; it is meaningless here). `[ordinal]` is a sweep request: `! query {{ [row]r, [ordinal]n }}`
- `KORU161` std/store:{s}({s}): a request block must name the row - add `[row]<name>`
- `KORU161` std/store:{s}({s}): continuation marker `|` used where an effect branch is required — `{s}` fires the effect arm `! {s}`, not `| {s}`
- `KORU161` std/store:{s}({s}): exactly one `! {s} {{ ... }}` branch per site this rung
- `KORU161` std/store:{s}({s}): the {s} arm needs a row binding: `! {s} <row> |> ...`
- `KORU161` std/store:{s}({s}): unknown request `[{s}]` on '{s}' - a {s} arm understands [row] and [id]

## `std/store:clear` (4 refusals — fired 0× in the corpus)
- `KORU161` std/store:clear requires a store name: clear(name)
- `KORU161` std/store:clear({s}): this store carries a `! removed` arm and no `! cleared` arm. `clear` does NOT fire `! removed` - firing it once per row is exactly the cost `clear` exists to remove - so declare `! cleared <count>` to say what emptying means for this store's observers, or remove rows with `std/store:take`
- `KORU161` std/store:clear({s}): this store has an OWNED column, and an owned row carries an obligation that discharges one at a time - emptying in bulk would drop them on the floor with nothing to report it. Remove rows with `std/store:take`, which hands each row's obligation back through `| item`
- `KORU161` std/store:clear({s}): unknown store, or a store shape without a clear unit this rung (singleton stores hold one row and are written with `std/store:stored`)

## `std/store:preorder` (4 refusals — fired 0× in the corpus)
- `KORU161` std/store:preorder requires a store name: preorder(name)
- `KORU161` std/store:preorder({s}): preorder needs a [tree] store - '{s}' has no synthesized parent column (declare it as [tree]std/store:new({s}) {{ ... }})
- `KORU161` std/store:preorder({s}): the preorder precedes its store's create in source - declare the store first
- `KORU161` std/store:preorder({s}): unknown store - no std/store:new({s}) found (preorder walks a [tree] container store)

## `std/store:stripe` (2 refusals — fired 0× in the corpus)
- `KORU161` std/store:stripe requires a store name: stripe(name)
- `KORU161` std/store:stripe({s}): unknown store, or a store shape without a stripe unit this rung (plural / {{old,new}}-mode stripe is a later slice)

## `std/store:view` (5 refusals — fired 0× in the corpus)
- `KORU161` std/store:view requires a member block: view(name) {{ Member1, Member2 }}
- `KORU161` std/store:view requires a view name: view(name)
- `KORU161` std/store:view({s}): a store view must name at least one member store
- `KORU161` std/store:view({s}): member '{s}': leaf '{s}' as '{s}' collides with '{s}' — one bare name, one identity; type-divergent same-name leaves across a view are refused
- `KORU161` std/store:view({s}): unknown member store '{s}' — no std/store:new({s}) found

## `std/store:watch` (8 refusals — fired 0× in the corpus)
- `KORU161` std/store:watch requires a store name: watch(name)
- `KORU161` std/store:watch({s}): '{s}' is not a field of store '{s}'
- `KORU161` std/store:watch({s}): '{s}' names no column - a one-column store names none, so its watch arm is the store: `! {s} <binding> |> ...`
- `KORU161` std/store:watch({s}): field '{s}' is watched more than once - multi-watch sequencing is pinned at 690_010
- `KORU161` std/store:watch({s}): nested watch splicing is a later slice - place the watch at top level for now
- `KORU161` std/store:watch({s}): the watch precedes its store's create in source - declare the store first (rung-one ordering)
- `KORU161` std/store:watch({s}): unknown store - no std/store:new({s}) found
- `KORU161` std/store:watch({s}): watch over a DRAIN store (ambiguous discharger) is a later rung - the write surface needs the canonical discharger to evict the old value (690_062), which *{s}:{s} does not have (declare exactly one, or drop the watch)

## `std/switch:char` (3 refusals — fired 0× in the corpus)
- `KORU167` std/switch:char requires a value argument: char(<expression>)
- `KORU167` std/switch:char: empty branch pattern
- `KORU167` std/switch:char: invalid range `{s}` (low > high)

## `std/trellis:check` (1 refusals — fired 0× in the corpus)
- `KORU165` std/trellis:check requires a trellis name: check(\\"<name>\\")

## `std/trellis:enforce` (1 refusals — fired 0× in the corpus)
- `KORU165` std/trellis:enforce requires a trellis name: enforce(\\"<name>\\")

## `std/types:proto` (1 refusals — fired 0× in the corpus)
- `KORU173` std/types:proto: the entry name '{s}' is not usable — a proto name must be an identifier (a-z, A-Z, 0-9, '_', '-'; no leading digit)

## `std/vendor:bindings` (2 refusals — fired 0× in the corpus)
- `KORU171` std/vendor:bindings requires a block: bindings {{ module: ./path }}
- `KORU171` std/vendor:bindings — {s}
