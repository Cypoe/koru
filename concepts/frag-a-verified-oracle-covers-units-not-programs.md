---
type: belief
id: frag-a-verified-oracle-covers-units-not-programs
provenance: verify-path session 2026-10-11 — ccomp-produced .o linked into a zig binary (demonstrated in an aarch64-linux container), then recognized as the same seam |mlir already rides
ts: 2026-10-11
---

# A verified oracle's coverage is a lane assignment, not a program verdict (belief)

Whole-program parity — all-zig binary vs all-ccomp binary, compare stdout —
makes the oracle's coverage binary per program: one unexpressible construct
refuses the entire file, and the refusal table is a wall. The link seam
dissolves that. Demonstrated this session: `ccomp -c` produces a standard ELF
object, `zig build-exe` links it, the mixed binary runs and calls across the
boundary. So arm A can be zig-everything while arm B is zig for the non-C
units plus ccomp for the C-expressible units — and then the only controlled
variable in the comparison is *who compiled the C fragment*.

That is a stronger instrument than it looks. A zig miscompile inside a non-C
unit lands identically in both arms and cancels out of the comparison —
the oracle's verdict localizes to the fragment automatically, no harness
attribution needed. Coverage becomes each program's C-fraction instead of
requiring C-fraction == 1, and "cannot lower to C" stops being a refusal —
it becomes an entry in a coverage map.

The mechanism is not new, which is the other half of the belief: `|mlir` proc
bodies already AOT-compile to `.o` and link into the output binary through a
glob in generated `build_output.zig`, and `~std/build:requires` exposes the
same splice to users. A `|c` variant rides an existing seam — find it before
you build it applied to a foreign toolchain.

## What constrains the partition

Calls cross the seam; memory does not. Zig and C guarantee no common struct
layout, so shared state must flow through accessor functions — the cut runs
along call edges, not data edges. (The c-lane lowering table's "closed
accessor set → static" is the same boundary seen from the other side.)

## Open

Whether the partition machinery earns its cost before whole-program parity
exists at all. Current sequencing: whole-program first — the first green
cell needs zero partitioning — with the partition as the generalization that
makes the oracle reach past the sequential fragment.

## Evolve 2026-10-22 — the fragment's vocabulary, not its boundary, was the benchmark wall

Measured on the race corpus: the barrier holding live benchmarks out of the
C lane was not the fragment boundary (store views, watches, effect arms —
the refused census names them) but one missing builtin row: `@as`/`@intCast`,
the canonical counted-loop cast. Widening `lowerCInto` to the cast+arithmetic
family — `@as`, `@intCast`, `@floatFromInt`, `@divTrunc`, `@rem`, `@mod` —
moved 004/005 to whole-program parity immediately (`checksum 213186560` on
both lanes; ccomp ~20× slower, identical answer). The coverage lever is
expression vocabulary first, construct boundary second; the remaining wall
(KORU161 store surfaces, `RefusedConstruct` effect arms, `.kcs` raw host
lines) is the true fragment edge.

The faithfulness constraint that shapes the table: Zig's `@intCast` traps
out of range, so the lowering spells a checked helper (`__koru_intcast`)
rather than a bare C cast — a silent truncation would make the verified
binary less honest than the zig one it oracles. Residuals documented at the
table: usize sources ≥2^63, bare `@intCast` coercions — divergences the
race still surfaces as a verdict mismatch, not hidden wrongness.

## Evolve 2026-10-23 — a verbatim row that lies is worse than a refusal

The fragment's vow is "refuse what it cannot spell faithfully" — the cast
rung kept it by checking `@intCast`. The `==`/`!=` pair broke it differently:
it emitted *verbatim*, compiled clean under ccomp, and answered pointer
equality where Koru means value equality — a wrong verdict wearing a green
emit. Coverage-by-compilation is not coverage-by-verdict; an oracle that
silently diverges is worse than one that refuses, because the refusal is
audible.

The fix was possible only because the binding registry (`int_bindings`,
misnamed — it carries every minted cell's C type) already resolved string
cells to `const char *`: `__koru_streq` now emits whenever an operand types
as a string (a `"` literal or a registered binding), and unproven pairs keep
the verbatim residual rather than guess — the same discipline the wrap ops
apply to width. The residual class is member-read-vs-member-read and call
results: narrower than the old all-verbatim gap, never zero at the text
level.

Found in the same pass, on the *other* lane: the zig emitter's string-eq
block hard-labeled `blk:`, which collided with any enclosing labeled block
(arrow bodies, result binds) — string `==` inside an inlined body refused
natively while the C lane it oracles handled the case fine. Now gensym'd
`__koru_eq{d}` per emitted block. Lesson folded in: label collisions are a
class — any generated Zig label that isn't unique-per-emission is a latent
collision; `__koru_str` stays fixed because it can never nest inside itself.

## Evolve 2026-10-23 — `*X` rides as `struct X *`; opacity is the oracle's job

The largest single `no C type` bucket (~261 first-diagnostic rows) was
pointer cells — `*Bridge`, `*String`, `*List_i64`, `*Handle`, `*const
ast.Flow`, `*std/bridge:Bridge<session>` — and it was vocabulary again, not
boundary: an opaque handle needs no representation, only a name C can
carry. `cTypeOfResolved` now answers in three shapes: `Tok *` when a proto
terminal's scalar minted a C typedef (the alias arm also checks the scalar
HAS a C type — an `i128` terminal's `*Tok` gets `struct Tok *`, not a
typedef name that does not exist); `int64_t *` for a primitive pointee;
and `struct <tag> *` — an incomplete type — for everything else. Incomplete
is the point: declarations, parameters, fields, returns, bindings,
assignment and `==`/`!=` all compile, while dereference dies inside ccomp.
The oracle enforces opacity itself; no checker was added. Qualified and
generic pointees mangle to the same `_`-joined tag the monomorphizer
spells (`List<i64>` → `List_i64`), so `*std/bridge:Bridge<session>` and
`*const ast.Flow` name consistent opaque identities.

The discipline is the frag's own vow, applied at the type level: `**X`,
`[*]X`, `*[4]X`, `*const` alone — a leading non-identifier char means the
pointee isn't a name, so the resolver refuses rather than silently drop a
level of indirection.

Companion fix on the zig lane: the runtime variant-proc loop already gated
foreign-language bodies out of `handler__<variant>` emission (`js`, `cs`,
`gpu`, …) — `c` was simply absent because no runnable `|c` proc existed
before. `|c` bodies are C host bytes; the list now carries the tag.
Measured consequence: of the 261 rows, 152 moved past the pointer
diagnostic — the next walls named are `NoCProcBody` (the `|c` proc
surface) and the record/slice/optional families — later rungs, not new
refusals.

## Evolve 2026-10-23 — `| x *` wildcard payloads mint a placeholder; the hole is honest

The `| x *` decl — "bindable payload, shape unspecified" — was a first-fragment
refusal on a member the zig lane already types honestly as `struct {}`: the
wildcard is a hole the *use site* fills (every bare `| x *` in koru_std lives
on a `[keyword]`/`[template]`/`[transform]` tor — `cond`, `json:parse`,
`spawn`, `std.parser:match`'s `` | `*` * `` — whose union never materializes
a real call). C99 has no empty struct, so the lane mints the same hole as a
named one-byte placeholder, `struct <ev>_<br>_t { char __koru_wildcard; }`.
The decl compiles; materialization refuses exactly where zig's does — a
`=> x v` produce is a named KORU047 (zig: a raw `expected struct {},
found i64` coercion error — same boundary, better sentence), and a bound
placeholder dies inside ccomp on any typed use. No checker, no `void *`,
no invented shape.

Measured: all 8 first-diagnostic wildcard rows (the `std.parser` family)
moved past — to `field expr has type Expression`, the comptime-AST input
type that is the transform surface's real boundary. Effect-side `! each *`
(`anytype` handler params) and `|*` catch-all consumers stay refused —
separate axes, not this rung.

## Evolve 2026-10-23 — `:.N` is `%.*f` — the toFixed spelling, not a new formatter

`{{ v:d:.N }}` refused on the grounds that dropping precision would change
output bytes — correct instinct, wrong conclusion: the lane already had
printf in the preamble, and `%.*f` IS the toFixed semantics `:.N` documents
(js emits `Number(v).toFixed(N)`; zig emits `{d:.N}`). The operand now
routes to `__koru_*_write_f64_prec(v, N)`; a wrong-typed operand fails at
the oracle's typecheck like every other placeholder. One honest caveat the
measurement surfaced: `{d:.N}` on an INT operand zig-prints bare (`5`, not
`5.000`) — zig ignores precision there while js honors it, so the lanes
already disagreed before this lane picked the toFixed side.

Two boundary notes: `io.cprec.kz` is line-pinned at 282 and `~part` decls
live in the pinned root (KORU204 bars nested parts) — the change was made
net-zero inside the file rather than grown. And `230_003`'s `@sin(0.5)`
now emits but reaches ccomp verbatim — math builtins are the next
operand-surface row, gated on `-lm` joining the pinned compile recipe
(that is a recipe ruling, not a lowering row).

## Evolve 2026-10-23 — `|c` proc bodies live in `.kc` facets; argv/stdin join the preamble

`NoCProcBody` was 236 first-diag rows but not one problem: most name
program-local tors (`input:*`, `app:*` — the tests' own `|zig`-only impls)
no stdlib facet can close. The stdlib subset is ~24 rows, and the honest
split is mechanical-vs-runtime: `set:new`/`map:new`/`fleet:claim`/
`compress:gzip`/`json:emit.free` each need a whole C runtime surface
(hash tables, lease files); implementing `new` alone would only move the
first refusal to `add`. Those stay refused.

The mechanical four landed: `args:count`, `args:get`, `io:free`,
`io:readln` — and they established the facet pattern rather than widening
pinned files. `.kc` is already a recognized extension auto-merged by stem
(file_types.zig), so `args.kc`/`io.kc` carry `~proc name|c { host-C }`
bodies without touching the at-pin `.kz` roots. The bodies see
`emitFieldBindings` locals and return `struct <ev>_res` ctors — same
contract the `[template]` `|c` procs already used, now for runtime procs.

Two preamble/runtime pieces joined: `main` is now
`int main(int argc, char **argv)` feeding `__koru_argc`/`__koru_argv`
statics (argv index 0 is the program name, matching `std.os.argv`), and
`__koru_readln_buf[8192]` backs `readln`'s valid-until-next-call contract.
Two type mappings joined: `[:0]u8` → `const char *` (a sentinel slice IS
a C string — `argv[i]` literally), and `cTypeOfResolved` strips phantom
`<...>` qualifiers — `string<!allocated>` is the string cell; the phantom
marks the obligation, not the runtime shape. `List_i64<list!>` strips to
`List_i64` and still finds no C type — the strip only re-homes phantoms.

Measured: 3/3 first-diag rows moved past — `io:free` → `input:wrap`
(program-local, correctly still refused), `args:count` → `node kind
'assignment'` (the sequential-fragment wall, a different ruling).
`230_015_args_readln_cross_target` proves count/get/readln byte-identical
zig-vs-ccomp through the suite's own ARGS+STDIN feeding.

## Evolve 2026-10-23 — `u6` rides a `uint8_t`; `@@typeInfo` is a comptime surface, not a lowering row

Two investigations closed one mechanical row. `@@as(u6, @intCast(i))` —
the spelling the AoC corpus reaches via template splice — failed at
KORU120 because `lowerCBuiltin`'s `as` arm asks `cTypeOf` for the target
and `u6` had no cell. The honest carrier is `uint8_t`: a `u6` value only
enters through `@intCast` (now spelled `__koru_intcast(v, 0, 63)`, the
same trap zig's safety check fires) or literals the Koru frontend already
bounds, so the byte cell never sees 64..255. Two rows — `cTypeOf` plus
`C_INTCAST_BOUNDS` — and 9 AoC files moved past KORU120 to `!` effect
arms, the resumable-semantics axis that stays parked.

`@@typeInfo` resolves differently: the `@@` prefix is only how a
template splices a builtin into emitted text — the filter feeds
`lowerCBuiltin` the plain `@typeInfo`. Every `@@`-spelled builtin shares
the lane's expression table; KORU120 is the render-time twin of KORU047,
not a separate fragment. But `@typeInfo` itself is comptime reflection —
the zig lane interrogates the type system while compiling, and C has no
compile-time type query to lower it *to*. It correctly stays refused: a
C-side runtime type registry is a ruling about what reflection means
under the oracle, not a mechanical row.

## Evolve 2026-10-23 — comptime cells are holes; the oracle certifies up TO the boundary

`Expression`/`Source` — the compiler's own AST types — reach input
records on comptime-surface events as fields the C lane can never
observe. The faithful cell is a nominal one-byte placeholder
(`struct __koru_comptime_*`), and the call-site arg emits `{0}` — the
source expression is comptime cargo, not a C expression. Nominal tags
keep distinct holes from binding across each other; the `__koru_`
prefix can never collide with a proto-typedef'd name. `Source<HTML>` —
`ast.Source` with a source-vocabulary tag — strips to the same cell
through the phantom arm. 10/10 probed rows moved past to their real
walls (parser `NoCProcBody`, `i128`, record returns).

The framing this lands in: ccomp certifies everything UP TO the
boundary — concurrency and raw host lines are not "the oracle fails
here" but "verification ends here"; what crosses the boundary gets
Alive2-class static analysis on the far side, not a semantic blessing.
Every rung so far follows that shape: a wall is a *verified absence*
(wildcard placeholder, opaque pointer, comptime hole) or an honest
boundary sentence — never a silently-altered semantic.

The zig implementation answers every representation question that
survives: slices are `{ptr, len}` fat by definition; `!` effects are
per-call-site splices into shared scope (fs.kz documents the inline —
ambient bindings are plain locals, no env exists); `std/rings` is a
sequential data structure misclassified by the concurrency name-match.
What is left is machinery, not semantics.
