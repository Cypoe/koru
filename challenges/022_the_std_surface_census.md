---
challenge: std-surface-census
kind: frame
status: standing
yields: one std namespace measured — every pub tor classified live / transform-target / internal / dead — plus the seams it names
family: toolchain
---

*Walker context — the recurrence that earned this frame. `koru_std` was not
designed; it accreted, and it shows. A call-site census (2026-09-11, ~4,000
consumer files across the suite, koru-libs, kopium, orisha) found **136 of 298
pub tors with zero `std/pkg:tor` call sites** — and that number is *wrong in
both directions*: the comptime transforms emit calls no grep can see
(`std/list:new(i64)` rewrites to `new-i64`; `push(xs,v)` routes through
`routeOpCall` to `push-i64` or a proto-synthesized container), so "zero call
sites" overcounts the dead, while a tor reachable only through a rewrite is
still invisible surface nobody designed. Both errors are the same fact:
**std has a hidden layer, and nobody has mapped it.**

*The seams are already named where eyes have landed: `std/io` alone carries
three naming generations (`readln` / `read.ln`; `eprint` / `eprint.ln` /
`eprintln`; `print` / `print.ln` / `print.blk` + exported `*.impl` internals),
`read-lines` exists in BOTH `io` and `fs`, `fs` is two tors wide and its
`write` cannot refuse creation (kopium hole 6), `std/json` is a husk beside
`koru/yyjson`, and whole packages (`env`, `table`, `eval`, `testing`,
`net:tcp.*`, `http:*`) sit at or near zero consumer reach. Each of those was
found by accident, mid-build — that is the recurrence.*

*This is 008's measurement half and 009's intake. 008 finds what the surface
LACKS by writing forward; 009 dedupes what exists; this frame reads the surface
AS IT IS and says what it actually is. Its census entries are the feedstock
for both.*

---

## The brief (sealed — you are the contestant)

Pick **one `std` namespace not already censused** (`challenges/std-census/` is
the catalog — read it first). Measure it. Classify every `~pub tor`:

- **live** — direct call sites in consumers exist
- **transform-target** — reachable only through a `~[comptime|transform]`
  rewrite (name the router: `routeOpCall`, segment strings, `synthesize*`)
- **internal** — driven by the pipeline/driver, not by programs
- **dead** — none of the above

Then name the seams: tors duplicated across namespaces or spelling
generations, refusal arms the namespace SHOULD have and doesn't, params whose
ownership story no caller can satisfy.

Append one `NNN_<namespace>.md` to `challenges/std-census/` with the table,
the seam list, and the one-line verdict: is this organ designed or evolved.

Do not ask which namespace. Count, pick one, ship it. A namespace with one
censused file is done; do not re-measure it. `io`, `store`, `string`, `fs`,
`list`, `grid`, `fmt`, `time`, `env`, `net`, `http`, `json`, `map`, `set`,
`field`, `table`, `eval`, `testing`, `trellis`, `template`, `todo`, `regex`,
`proto`, `koru`, `types`, `control`, `void`, `foreign`, `invariants`,
`constructor`, `vendor`, `package`, `deps`, `simple`, `inter`, `rings`,
`rules`, `crypto`, `gpu`, `args`, `benchmarking` — and the compiler-internal
set (`compiler*`, `parser`, `emitter`, `eval` pipeline files) is in scope too,
classified `internal` where that is what they are.

## ⚖️ VARIANCE IS THE METRIC

Different namespace each replay. The catalog IS the map — a namespace already
censused is a replay spent re-measuring, which is this challenge failing at
its own subject.

## Done-gates

- The census entry exists on disk, one file, the table is complete (every
  `~pub tor` in the namespace classified — a row per tor, not a summary).
- Every `transform-target` row names the emitting transform.
- Every `dead` row was checked for emitted-name reachability, not just call
  sites (`grep` the transform bodies for the tor's routed name before
  writing `dead` — the list `-i64` family is the cautionary tale).
- Every claimed seam is verified in source this session — quoted, not
  remembered.
- The verdict line is one sentence, honest.
