---
type: belief
id: frag-an-arm-s-sigil-is-part-of-the-binding-s-type
provenance: 2026-10-13 — the stored-write check's deferred residue: `e.hp`
  query-row reads, `(&S.f)[i]` lowered reads, and `! inserted|removed|updated`
  payload puns all typed to nothing through the scope env alone
ts: 2026-10-13
resource: src/emitter_helpers.zig
---

# An arm's sigil is part of the binding's type — the scope env cannot say what a name is

`scopeAtSite` hands a checker a flat `name → type` table, and for three
binding families that table is **wrong or empty by construction**:

- `| row r` and `! row e` are the same word split by sigil: the terminal
  arm binds the row *index* (`usize`), the effect arm binds the row
  *record* (`e.hp` reads columns). On the decl the record arm inherits the
  same-named terminal branch's payload — `e` wears `usize` while binding a
  record, so a scope read that trusts the stamped type misclassifies by
  design, not by accident.
- `! inserted { hp }`/`! removed { hp }` destructure fields **pun store
  columns** — and user type text on them is *refused* (KORU161), so an
  untyped pun binding is the only shape that exists. `! updated { old,
  new }` binds the written field's images under a decl-enforced uniform
  column type; `old`/`new` name no column at all.
- The lowered row read `(&__koru_store_S.f)[i]` is **compiler-internal
  text, not expression grammar**: `&` has no unary form and a grouped
  primary takes no postfix, so the surface parser fails it wholesale —
  a check that feeds compiler-produced text to the surface grammar
  measures its own grammar, not the program.

The fix shape that fell out: keep the scope env for what it can say, then
walk the *site's arm ancestry* for what it can't — `rowBindStoreAtSite`
matches `cont.binding` on sigil-checked arm names, `lifecyclePunAtSite`
matches `cont.destructure` fields on interceptor arms, and the value text
is normalized (`(&x)[i]` → `x[i]`) before the surface parser sees it.

Measured by the corpus harvest before the walk existed: `e.hp`-shaped row
reads and interceptor payloads were the bulk of `deferred`; after, 690_041
reports all seven writes `i64<-i64 lossless`.

The half-rule this belongs to is the same one `frag-a-check-and-its-
satisfier-must-enumerate-the-same-set` guards: the *satisfier* here is a
name resolution, and it is only satisfied when it enumerates the same
binding space the compiler's scoping does — scope env PLUS arm kind PLUS
lowered spellings. Any one of the three alone under-counts, and
under-counting reads as `deferred`, never as a refusal — silent by design.
