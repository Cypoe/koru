---
type: belief
id: frag-ctx-matching-is-name-plus-type
provenance: koru_std/ctx.kz typed matching — 696_011/696_012 pins,
  probe_ctx_type.k (2026-10-19)
ts: 2026-10-19
---

# ctx scope matching is name + exact canonical type — mistyped names fall through

A `std/ctx` scope's fields match callee params on name AND type, not name
alone. A same-named column whose type cannot serve the param does not
shadow: it falls through to outer scopes, so `ctx(outer) |> ctx(inner)`
with `inner.a:f64`/`outer.a:i64` feeds `a: i64` params from outer and
`a: f64` params from inner — the same stack answers the same name
differently per callee signature. "Innermost wins" became "innermost
compatible wins"; scope selection is typed, not merely positional.

The ruling behind it: exact canonical-string comparison only — `i64`
serves `i64`; there is no coercion lattice, no widening. A param no
compatible scope provides stays unfilled and refuses through the ordinary
missing-input path (696_002's "injection adds no new error path" survives
— KORU080 does the refusing).

Mechanics that fell out:

- Column types come from the `std/store:new` seed rhs: `9[i64]` peels to
  `i64` (struct_literal.peelBaseType's rule, mirrored — transform code
  cannot import it), a bare spelling (`i64`, `Sample`, `*T<state!>`) is
  the type, `<...>` phantom is stripped to match Field.type's canonical
  form.
- A bare-literal seed (`a: 0`, `a: "x"`) yields no readable type: the
  column wildcard-matches by name, exactly the old behavior — unknown is
  not wrong.
- Module-qualified columns (`*app/lib/pend:Pending`) compare against
  `module_path:type` reconstructed from the Field, both separator
  spellings tried.
- Shadowing-by-name alone survives nowhere: every place that asked "does
  a scope provide this name" (`inject`, `injectableCount`) shares
  `matchingCol`, so consume-detection and injection cannot diverge.

Pinned: 696_011 (typed fall-through both directions), 696_012 (name-only-
mistyped refuses `requires input 'a'`). Consumes: the projection-scope
intent — `std/ctx { fs: theme[r].fs, sel: docs[cur] }` presenting
ScopeBinding-shaped {name, type, value_ref} triples — is recorded as a
TODO in koru_std/ctx.kz; projected fields get their type from the backing
store path where resolvable.
