---
type: belief
id: frag-a-textual-substitution-over-source-needs-a-code-mask
provenance: 690_267 — a rule arm's row rewrite corrupted a string literal, the second site of the same defect after 230_016
ts: 2026-08-08
---

# A textual substitution over source needs a code/text mask, and having one in the file is not having one at the site (belief)

Koru rewrites source text in several places: the visitor emitter renames
identifiers that collide, the store rewrites `<row>.<column>` into a cell read,
transforms splice rendered bodies. Each is a find-and-replace over a string that
is *mostly* code and *partly* not.

Twice now the same defect has shipped. On 2026-08-07 the visitor emitter
rewrote user identifiers inside string literals, so a message reading
`"a count above zero"` shipped as `"a __koru_event_input.count above zero"` —
compiled, ran, no complaint (230_016). On 2026-08-08 the store's rule-arm
rewrite did the same at a different site: a literal `"e.label is a column"`
became a Zig cell read stored as the row's text, silent on the JS lane and an
unreadable Zig error on the other (690_267).

**The second one is the instructive one, because the mask was already there.**
`entityRefs` computes `ast.expressionMask` at its head. It consulted it in
exactly one branch — the bare identity binding — and not in the
`<bind>.<column>` branch, which is the shape every rule arm uses. So the
protection existed, was paid for, and covered the rare case while the common
case went bare. Reading the function top-to-bottom shows a mask being computed
and looks correct.

So the belief has two halves. The first is ordinary: **any substitution over
source gets a code/text mask, never a special case per known-bad input.** The
second is the one that costs time: **a mechanism being present in a file is not
evidence it is applied at the site that matters.** Grep for the mask and you
find it; grep for the substitution and you find several, and only some consult
it. The check is per-substitution, not per-file.

The subtlety that makes this more than "skip strings": **interpolation inside a
literal IS expression context.** `print.ln("v={{ e.v:d }}")` reads a column
from within a string and must keep working. A mask that skipped literals
wholesale would break every rule arm that prints — and would have looked like
the fix, passed casual inspection, and failed a different set of tests. Both
pins carry that control in the same file as the defect for exactly that reason.

Third site, 2026-09-17, and a new wrinkle: this time the mask WAS consulted
and still shipped the defect. `{{ d.id:d }}` inside a sweep body emitted the
row's `__koru_handle_of` mint into the *format placeholder* — the rewriter
correctly stayed out of the literal and correctly entered the interpolation,
but the mask's model of "expression context" stopped at the placeholder
boundary, while the io transform's contract splits `{{ expr:spec }}` at the
first `:`. The spec tail is a THIRD class — neither literal text nor
expression — so "is this inside `{{ }}`" is not the whole question; inside
one, only the text before the first `:` is an expression (690_122/124/192,
fixed in `expressionMask` itself so all twelve rewriter sites get it). The
belief sharpens: a consulted mask can still be wrong — the mask's model of
context has to match the downstream parser's grammar, not just the
code/string boundary.

Fourth site, 2026-09-23, and the sharpest version yet: `replaceIdentifier` —
the bound-name rewrite behind `__koru_arg_<n>_<u>` mints — consulted the code
mask faithfully (strings and comments untouched, keyword positions handled)
and still corrupted the program, because "code" is not one context. `.name`
in Zig is a MEMBER name — struct-literal label, member access, enum literal —
bound to the left side's namespace, never a reference to the in-scope
identifier. Kopium's `live.k` emitted `p.* = .{ .__koru_arg_m_0 = ... }`
against koru_curl's library-declared `Pending` and the backend compile
refused a field that exists nowhere (230_023). Two compounding subtleties,
both pinned: a naive "skip when preceded by `.`" passes the compile while
shipping the wrong bound value, because `0..m`'s range end IS the reference
(`..` is not member position); and the same corruption inside the body
self-heals — a struct decl in the spliced text flips along with its uses, so
the defect only ever breaks when the type lives outside the rewrite's reach,
which is exactly the library-code case. The belief sharpens a third time: the
mask must model REFERENCE position, not merely code — inside code, "is this
identifier a reference or a name in someone else's namespace" is the next
question down, and `..` keeps it honest.

Fifth site, 2026-10-03, and the inverse of every earlier one: the mask was
consulted, the mask was RIGHT — and the defect still shipped, because the
format placeholder lived where no literal exists. `{{ s.ip:s }}` inside an
unquoted `fmt.blk` block (Source text, not a `"…"` argument) had its `:s`
SPEC rewritten to `__koru_store_Sessions.__koru_handle_of(…)` by
`store.qrewrite`'s bare-binding branch — the emitted Zig format string
became `{__koru_store_Sessions.__koru_handle_of(__koru_sdix_s_L33)}` and
died in Writer.zig, "cannot format slice without a specifier". The site-3
fix taught `expressionMask` the `{{ expr:spec }}` third class, but that
grammar only exists inside literals; in a Source block the mask sees one
uniform expression context and the spec tail has nowhere to hide. The
fix is per-site again — `:`-glued names are spec/qualifier position and a
row handle is never spelled that way — not another widening of the mask:
the mask cannot classify what it cannot delimit. The belief sharpens a
fourth time: **the third class re-forms at every unquoted placeholder
surface; each rewriter that reads bare bindings must refuse `:`-glued
positions itself**, because the mask's grammar ends at the literal edge.

Open: nothing enumerates the substitution sites, and nothing enumerates the
unquoted Source grammars either — `fmt.blk` blocks are the one that shipped
a defect; any other transform that consumes a bare `{…}` body carrying
`{{ }}` placeholders (or a `:` grammar of its own) is the same hole waiting
for its first `s`/`d`/`f`-named binding. The known substitution sites
(visitor_emitter, store's entityRefs, store's bindStrip, qrewrite's refs)
still have no list.
