---
type: belief
id: frag-std-refine-defines-facets-consumers-enforce
provenance: koru session 2026-09-15 — refine v1: proto-anchor meet, cross-home layering, confluent fold; 671_001..671_006 pin the semantics
ts: 2026-09-15
tags: [koru, stdlib, refine, proto, constraints, comptime, transforms]
---

# std/refine defines facets on abstracts; enforcement is the consumer's

`std/refine` is a **definition layer**, not an enforcer. Both `std/proto`
and `std/refine` live on abstract declarations — proto owns nominal
structure (`name: type` fields), refine owns predicate facets
(`name: type & bound…`) — and neither ever sees a concrete value. A value
becomes bound by a constraint exactly when it crosses a *consumer's*
boundary (`std/list:push`, `std/store` insert, `std/json` decode), so the
boundary is where enforcement lives. An unconsumed facet is enumerable
documentation, not a hole.

Mechanics, all library-level over existing machinery:

- `std/refine(Name)` resolves `Name` against the refining scope's home;
  `std/refine(home/path:Name)` addresses a declaration in another home —
  the qualified spelling rides the named-arg channel (`name=home/path`,
  `value=Name`, `had_explicit_label`), proto's own `app/alpha:Health`
  convention with no strings. Bare names are never a program-wide
  search — same rule proto uses for field references.
- The anchor is found in a live `std/proto` invocation OR its erased
  `// proto Name: …` marker, so dissolution order doesn't matter.
- Every refined field must exist on the anchor and its base must agree —
  a meet needs one base, not two.
- Multiple `std/refine` blocks — in the same module or layered across
  modules — fold onto one facet; whichever transform fires first leaves the
  canonical facet in the program tree as a typed `Item.facet_decl` node
  (name + logical home + fields carrying structured `lo`/`hi`/`eq` bounds —
  integers, not text). Later sites see the node and dissolve to a
  tombstone comment. The meet is confluent by construction.
- Inter-transform state is a typed AST node, never a comment: the emitter
  *renders* `// refine home:Name: …` into generated Zig for debugging, but
  nothing parses that text back.
- Empty meets (`>20000 & <=1000`), unknown fields, base mismatches, and
  missing anchors all refuse at KORU205, naming the disagreement.

Layering is the reason refine is a separate module rather than `&` inside
proto's own grammar: a library declares `std/proto(Server)` plainly and a
downstream module tightens `port` without editing the library. Inline `&`
inside proto remains reachable later — proto could call refine's parser —
but the two spellings must meet the same facet.

The first enforcing consumer landed: `std/list` reads `.facet_decl` off
`program.items` and emits bounds guards into `push-<Name>`'s body. The
violation is a **panic branch**, not an inline trap: `push` declares
`| ?ok`, `| ?!violated string` (the offending field's flat name), and
`| ?!oom` — the guard produces `.violated` into the union, the append
returns `.oom`, success returns `.ok`. Unhandled, the call site gets
the synthesized `@panic` — same loudness as before, and the arm echoes
the payload to stderr first (`payload: port`) so the field name reaches
the crash log. Handled (`| violated f |>`), the caller supervises and
survives — a JSON decoder's recoverable parse error is exactly this
arm, and `| violated f |> => violated f` re-raises into an enclosing
event's own `?!` decl. The cost of refusal is now *in push's type*,
not buried in its body. Two mechanics the landing pinned: refine runs
at the `|pre` transform stage so `facet_decl` nodes exist before any
`.main` consumer walks the tree (ordering by stage, not by dissolution
luck); and the enforcement protocol is a **shared comptime surface** —
`ast_functional.facets` carries facet resolution (`find`, `protoHome`,
`flat`), the boundary guard (`guardBody`), and the canonical branch
contract (`enforceBranches`: `?ok` + `?!violated` + caller-named panic
extras). A consumer's transform calls facts, never re-derives
`facet_decl` layout — consumer-owned means the *policy* is the
consumer's (where the boundary sits, that list's extras include `oom`),
not the protocol. The earlier "each consumer keeps its own scanner"
belief held exactly one consumer; with the machinery factored, a second
enforcer costs its judgment, not a re-implementation.

The landing also corrected `std/list`'s element semantics — the
enforcement story only works if the boundary sees what it constrains:
a proto element was a newtype over its FIRST field (`pub const Server =
i64`), silently dropping `retries`/`host` — fields the facet bounded.
The element is now the record: `Server = struct { port: i64, host:
[]const u8 }`, `push` spells every field by name (the `store:insert`
convention — `push(xs, port: 8080, host: "x")`), and nested protos
flatten to leaf columns (`pos.x` → `pos_x`). One honest seam remains:
a bare proto element whose decl already erased to a `// proto` marker
has no home left to match — the facet falls back to name-only identity,
the proto marker reader's own rule. A typed `proto_decl` (the next
namespace off the wire) restores home scoping.

Open rungs: disjunction-with-default atoms; non-integer bases;
enforcement at other boundaries (std/store insert, std/json decode).

Pins: 671_001 (meet), 671_002 (empty meet refused), 671_003 (cross-home
layering), 671_004 (unknown field), 671_005 (base mismatch), 671_006
(confluent blocks), 671_007 (unhandled `?!violated` traps, payload
echoed), 671_008 (push admits through the guard), 671_009 (handled
`| violated f |>` survives the bad push), 671_010 (`=> violated f`
re-raises across an event boundary — the outer caller supervises).
