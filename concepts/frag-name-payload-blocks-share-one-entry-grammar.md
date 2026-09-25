---
type: belief
id: frag-name-payload-blocks-share-one-entry-grammar
provenance: tightening replay 15 review 2026-09-25 — Lars proposed coupling the const-block and proto-block languages; measured against the tree before answering
ts: 2026-09-25
tags: [koru, field-list, proto, const, source-block, grammar]
---

# Every `{ name: payload }` block speaks one entry grammar; the consumer owns only the payload's meaning (belief)

`const { … }`, the proto doors (`std/types:proto`, `std/proto`, `std/n`), store
seeds, capture blocks, kernel field lists — all are the same surface shape:
entries of `name: payload`. The grammar that *couples* them is the entry layer:
an entry has a name and a payload, entries separate per the door's convention,
and the same four faults are refused with the same vocabulary — nameless,
typeless, fused for want of a separator, and a name bound twice.

Payload interpretation is NOT shared. `const` lowers expressions, proto checks
its type vocabulary (scalars this rung; compounds/`ref`/`<:` in `std/proto`),
store interprets write values. Coupling the grammar never means one payload
domain.

## The ruling (Lars, 2026-09-25)

Coupling the block languages is wanted, and two constraints bound it:

- **Unambiguous, and no comma litter.** In proto doors a comma is not a field
  separator — entries separate on lines, one `name: type` per line. A comma in
  a proto field list is a wart or a fused second field; it refuses, it does not
  parse. `const`/`table` keep comma-or-newline because their expression
  payloads already carry meaningful commas (`@as(i32, 5)`).
- **Hand-drawn is acceptable while the de-slop census runs.** Three hand-rolled
  line loops today (`types.kz` proto, `proto.kz`, `proto.resolve.kz`'s parent
  re-scan) plus the `parse_fields` template filter — a fourth honest copy beats
  a premature shared scanner; the census decides what deserves sharing.

## The measured hole is closed (2026-10)

The proto doors' line loops used to refuse a fused same-line entry with the
wrong reason (`unsupported type 'i32 serial: string'` — the fused tail
misread as part of the type) and never checked a name bound twice:
`proto(Dup) { rpm: i32 / rpm: i32 }` + `std/list:new(Dup)` reached Zig as
`duplicate struct member name 'rpm'` (measured 2026-09-25 at ab5ec044d).

Each of the three loops now keeps a seen-set and runs
`struct_literal.fusedFieldLine` on the payload before interpreting it —
exactly the fix the hole note prescribed, no shared scanner. Duplicate names
refuse `KORU173` ("field 'rpm' is bound twice — a proto entry takes each
field name once") at `std/types:proto`, `std/proto`, and the `<:` parent
re-parse; fused lines name the second field's fragment ("'serial: string'
began a new field on the same line"). Inherited-field merge semantics are
unchanged — the seen-set scopes to one block's text, so a child re-binding a
parent field still deduplicates rather than refusing. Pinned by
665_015–019.
