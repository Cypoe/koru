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
structure (`name: type` fields), refine owns facets (`name: type &
bound…`) — and neither ever sees a concrete value. A value becomes bound
by a constraint exactly when it crosses a *consumer's* boundary
(`std/list:push`, `std/store` insert, `std/json` decode), so the boundary
is where enforcement lives. An unconsumed facet is enumerable
documentation, not a hole.

Facets come in two term kinds. **Predicates** (`>1024`, `<=65535`,
`==x`) *test* the incoming value and refuse through `?!violated`.
**Normalizers** (`clamp(lo, hi)`) *rewrite* it — the boundary stores
the saturated value, declared on the field so the policy is visible in
the declaration, not hidden in a fixup. When a field carries both, the
order is forced: normalize first, then predicates judge the post-clamp
result (`clamp(0,65535) & >1024` on `80` still refuses). Two clamps on
one field meet by interval intersection; a clamp intersected to empty
or against bounds gone empty refuses at KORU205 like any empty meet.
Clamps bind integer scalars only.

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
- The spelled base may name a terminal: `port: Port & >1024` where `Port`
  minted by `std/proto:i64(Port)`. Legality resolves the base to its host
  scalar (live terminal door or erased marker, home-scoped, qualified
  `home/path:Name` supported), judged on the met field post-merge so a
  contributor's bound on a non-integer terminal refuses too. The facet
  keeps the declared base — the guard emits `port > 1024` and `Port = i64`
  carries it.
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
enforcement at remaining boundaries (std/json decode — std/store
insert landed 2026-09-16).

Pins: 671_001 (meet), 671_002 (empty meet refused), 671_003 (cross-home
layering), 671_004 (unknown field), 671_005 (base mismatch), 671_006
(confluent blocks), 671_007 (unhandled `?!violated` traps, payload
echoed), 671_008 (push admits through the guard), 671_009 (handled
`| violated f |>` survives the bad push), 671_010 (`=> violated f`
re-raises across an event boundary — the outer caller supervises),
671_011 (clamp saturates the stored value), 671_012 (bounds judge the
post-clamp value), 671_013 (clamp met to empty refuses), 671_014
(clamp∩clamp meets by intersection), 671_015 (bounds meet on a
terminal-typed field), 671_016 (clamp on a terminal-typed field),
671_017 (bound on a non-integer terminal refuses), 671_022 (equality
admits and refuses at the boundary), 671_023 (an equality contradicting
another equality refuses), 671_024 (two sibling blocks disagreeing on an
equality refuse — the confluence hole), 671_025 (a scoped equality
contradicting a universal one refuses), 671_026 (an equality outside its
own interval refuses), 671_027 (the equality reaches the store's own
guard builder), 671_028 (the catalog spells the equality and counts it
enforced).

---

EVOLVED 2026-09-16 (target-scoped facets; 671_020, 671_021): facets
gained a **scope**, and the dimension landed without a new spelling.
`std/refine(S)|fpga { … }` selects a declared impl variant — `|variant`
keeps its one meaning, implementation selection — and the selected impl
stamps `target` on the `facet_decl` it lands. The fold rule is the
load-bearing part: a block contributes to scope S iff its own tag is
`null` (universal — it governs every target) or equals S, so a `|fpga`
facet carries the meet of universal + fpga blocks while the universal
facet stays unscoped-only. One declaration program can therefore hold
several facets for one proto — the per-(home, name) uniqueness the
confluent fold assumed is now per-(home, name, target).

The consumer contract widened one notch, not one kind: `facets.find` /
`metFields(…, null)` still return the universal facet — every existing
enforcer reads exactly what it read before — and a target-aware
consumer asks for its scope (`facets.findFor`, `metFields(…, scope)`).
"Enforcement is the consumer's" now includes *which* facet to enforce;
a consumer that never names a scope enforces the universal one and is
not wrong for it.

The target vocabulary is **closed by declaration**: a tag with no
declared impl refuses KORU122 naming the declared variants, never
mints a facet under a name nobody reads — the same closed-vocabulary
stance as [[frag-panic-declinability-is-a-checker-stance]] (variance
that belongs to a declaration does not get a silent fallthrough). A
misspelled scope (`|fpg`) is a spelling error caught at declaration
time, not a divergent constraint set discovered at the boundary.

What would correct this: a scope tag with no declared impl silently
producing a facet (vocabulary re-opens), or a scoped facet leaking
into the universal read (a consumer that never asked for `|fpga`
suddenly judged by fpga bounds).

EVOLVED the same day (second enforcer; 690_321–690_326, 690_319
flipped): `std/store` insert is now an enforcing consumer — the `new`
transform reads the same `metFields` fold and declares `?!violated
<column>` on every generated insert event, so an out-of-bounds write
produces the panic branch, an unhandled one traps, and `| violated f
|>` supervises — the exact protocol std/list's push pioneered. The
explainer's honesty row flipped with it: "declared but NOT enforced"
was true while no consumer read the fold at insert; now it reports
what is enforced. Two honest scopings: insert reads the *universal*
facet today (`metFields(…, null)`) — a store that wants `|fpga`
enforcement names its scope at a later rung — and the explainer's
report and the guard share one fold, so what is reported is what is
enforced. The clamp-then-judge ordering held without a special case:
the boundary normalizes first, predicates see the post-clamp value.

EVOLVED the same day (first scope-aware consumer; 390_121–390_123):
`std/kernel:self|fpga` reads `metFields(…, "fpga")` — the target-aware
read the previous evolve specified, now realized. A new consumer *kind*
landed with it: the facet does not only judge values at a boundary, it
SHAPES the artifact — `i64 & >=0 & <=255` on the fpga scope emits
`input logic [7:0]` on the generated SystemVerilog stage, and the build
runs iverilog + vvp so a wrong circuit is a red compile. Enforcement
still rides the same fold: an init element the met port width cannot
carry refuses KORU123 — the facet enforced at the artifact's boundary.

EVOLVED the same day (width semantics ruled; 390_124, 390_125): the
truncate-vs-saturate question the previous paragraph left open is
answered by refine's own vocabulary — **bounds judge, clamp
normalizes**. Bare bounds size the port and arithmetic wraps (the
generated bench computes the map signed-wide and prints `note: …
truncated` where host and fabric diverge); a `clamp(lo,hi)` term in
the meet claims the boundary saturates, so the emitter generates
saturating logic and the bench notes "saturated" instead. Either way
the host-vs-fabric gap is printed, never silent and never a fail —
the facet governs the artifact's arithmetic, not the host's i64.
Signedness is the same read (390_126): a met range admitting
negatives (`lo < 0`, `== -N`, an unbounded i64) is `logic signed
[W-1:0]` with sign-extended wide math; `lo >= 0` stays unsigned and
refuses negatives at the boundary. The same build also runs
`yosys … check` on every `*.fpga.sv` — the artifact is gated
structurally (0 problems) and behaviorally (the sim), the way
spirv-val gates the [gpu] blob.

EVOLVED 2026-09-17 (equality is the one atom that cannot fold by
strength; 671_022–671_028): the confluence claim above was true of four
of the five v0 atoms and false of the fifth — which is worse than being
false of all of them, because the other four make the guarantee look
structural. Bounds and clamps fold by keeping the strongest term and
letting the emptiness judge rule on the result, so a disagreement
survives the fold and surfaces. An equality has no strongest term, and
the fold's "keep the first" turned two disagreeing equalities into a
DECLARATION-ORDER decision: two sibling blocks (`==8080`, `==9090`)
compiled, printed both facets as canonical, and enforced only the first
— `9090` rejected by the program that had just declared it, with no
refusal anywhere. The rule the fix encodes, and the one to hold the
next atom (disjunction) to: **an atom's meet either folds by strength,
or it RECORDS the disagreement for the emptiness judge — silence is not
a fold.** The atom is now pinned end to end, and the two fix sites have
a pin each, so a reverted half goes red.
