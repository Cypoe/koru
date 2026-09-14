---
type: belief
id: frag-a-create-spec-is-scoped-to-the-branch-that-carries-it
provenance: kopium wired hole 7 — headless/ledger.kz `post` re-issues `string<acct!>` on both `| ok` and `| bad-amount`; every call acquired one record per SPEC, so two posts left three undischarged records for one handle and hang-up dispatched the releaser until the module panicked on a dead slot
ts: 2026-09-14
---

# A create spec is scoped to the branch that carries it — the spec list is a menu, the dispatch result picks the row (belief)

The registry extracted one `CreateSpec` per phantom-carrying field it could
*find*, and the interpreter's acquire loop ran them *all*. For an event whose
branches each re-issue a handle — `| ok string<open!>` / `| bad-amount
string<open!>` — the declaration contains two create sites but any call fires
one. The pool booked both, every time.

The fix is not dedup and it is not "first spec wins" — both collapse the same
way on an event that genuinely mints twice. The spec itself had to learn its
branch: `CreateSpec.branch` names the outcome that carries the create (null on
a bare return, which has no outcome), and the acquire loop books a spec only
when it names the branch `dispatch_result` actually returned. The registry's
list is a *menu of what could be minted*; possession is booked per fired row.

## The same boundary, twice

Branch identity crosses the compiled/interpreted boundary in the source's own
spelling — `| bad-amount` parses through `flow_parser` unmangled — while a
dispatch outcome arrives as the mangled union tag `bad_amount`. Two comparison
sites compared them with raw `eql` and both lied: the create spec could never
have matched a hyphenated branch, and the *arm* `| bad-amount b |>` could
never have matched either — it fell to `unhandled-branch` while the outcome
sat in its payload. One comparator (`namesEql`, `-`≡`_` — the same fold
`ast_mangle` applies at parse) now serves both sites. The rule is the
language's own: `-` and `_` are the same character in a Koru name; any place
the interpreter compares names across that boundary owes the same fold.

## The deeper claim

The resource world is an inspectable statement of what is held. Before this,
it was inspectable and *wrong* — it reported a hold for a branch that never
ran. Every acquisition must be traceable to an outcome that occurred; a
declaration is a possibility, a dispatch is a fact.

Pinned by `440_022_branch_payload_acquires_once` (two `post`s — `ok` and
`bad-amount` — leave one held record each time; hang-up releases once).
