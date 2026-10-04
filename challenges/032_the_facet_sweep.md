---
challenge: facet-sweep
kind: commission
status: standing
yields: zero convertible .kz left in the tracked tree — the facet convention fully applied, held at zero by the gate
family: toolchain
created: 2026-10-04
---

*Walker context — the recurrence that earned this commission. The `.k`/`.kz`
split is parser-decidable, and the corpus had drifted: measured 2026-10-04,
144 of 1,526 tracked `.kz` files carry zero host items — pure Koru wearing
the host facet. Previous sweeps paid the number down and watched it regrow,
because nothing refused the next one. Two things landed that change the
shape: the `kz-extension-is-earned` gate row (commit `a1c58939f`) refuses a
staged convertible `.kz` at commit time — the wall that keeps the result at
zero — and `koruc <file.kz> to-k` does the mechanical half of each fix:
strip the leading `~`, emit `<stem>.k`, reparse under `.k` mode before
writing, refuse on any host item or existing output.*

*This is a **commission**, not a standing generator: it is finished when the
manifest reports zero in the convert lanes and every judgment row has a
verdict. The gate makes "stays finished" a property of the repo, not of
whoever last swept.*

---

## Ground yourself — regenerate, don't trust these numbers

    python3 scripts/kz_sweep_manifest.py --summary
    python3 scripts/kz_sweep_manifest.py --lane convert-test | head

State at 2026-10-04 (`git rev-parse HEAD` pins what you measure, not this):

| lane | files | meaning |
|---|---|---|
| `convert-test` | 0 | cleared 2026-10-04 — 23 converted, 2 facet-pinned keeps |
| `convert-other` | 0 | cleared 2026-10-04 — 26 converted, 4 module-part keeps |
| `error-pin-review` | 59 | CONVERTIBLE inside an error-marked dir — **judgment**: is `.kz` part of the pin or incidental? |
| `near-pure` | 59 | 1–3 host items, no proc — **judgment**: residue to drop, or load-bearing (e.g. `const std = @import("std")` feeding a template's `std.` calls)? |
| `exempt` | 36 | `expected.json` / `LANGUAGES` / `input.k` sibling / broken / allow-listed keeps — by-construction, not drift |
| `earned` | 1161 | honest `.kz` — do not touch |
| `unparseable` | 192 | error pins and `part` files — out of scope |

The manifest reuses `invariants/checks/check_kz_preference.exempted`, so the
exemption grammar lives in exactly one place. If you believe a row is
mislaned, the predicate to fix is `--check-k-convertible` or `exempted` —
not a local override in the manifest.

## The tool

    ./zig-out/bin/koruc <file.kz> to-k              # writes <stem>.k
    ./zig-out/bin/koruc <file.kz> to-k --stdout     # print, don't write

Behaviour, all verified against real tests: refuses non-`.kz` input, refuses
on any host item (`host_line` / `host_type_decl` / `proc_decl`, with counts),
refuses to overwrite an existing `.k`, reparses the stripped source under
`.k` mode before writing, and prints `remove <file>.kz; same-stem facets
merge` — the caller deletes the original, because a `.k` + `.kz` pair at one
stem merges into duplicate declarations. Verified 2026-10-04 on
`322_subflow_with_taps_pure_koru`: convert → `rm input.kz` → filtered
regression run green.

If `to-k` writes a `.k` that then fails its test or `-c`, that is an oracle
bug — the flag said convertible and wasn't. Stop and fix it in `src/`; do not
work around it in the file. Toolchain-first.

### Findings the first lanes earned (2026-10-04)

- **Oracle bug, found and fixed** (`0912ee290`): a kept multi-line gated
  import — `~[ … ]import app/x` in `.kz`, `[ … ]import app/x` in `.k` —
  died on `.k`'s own no-`~` wall: the parser rewrote the close line to
  `~import` and re-entered the loop, which refused its own synthesis.
  `310_113` converted, failed under `--profile`, and now permanently pins
  the kept `]import` path in `.k`.
- **The contract-split trap**: `CONVERTIBLE` counts host items, not module
  semantics. A `.k` in a module flips every `.kz` sibling into
  "implementation file" status — KORU111 then refuses each sibling's
  `~pub` decl. `koru_std/{index,bridge.run,compiler.directives,
  runtime.parsewire}` all parse clean and all four stay `.kz` for this
  reason — they are allow-listed, not converted. Rule for contestants:
  before converting a `koru_std/` or multi-part-module file, `ls` the
  stem's siblings; `.kz` siblings with `~pub` decls mean the conversion
  is a module-level decision, not a file-level one.
- **TODO dirs are not SUCCESS dirs**: `convert-other` caught every
  `input.kz` whose dir lacked `SUCCESS` — aspirational tests, KNOWN_BUG
  repros, module fixtures. Converting them is still correct (the repro
  is the source, not the extension), but verify the dir's standing
  state, don't invent a new expectation for it.

### Findings the judgment lanes earned (2026-10-05)

- **`error-pin-review` closed: 58/59 converted, zero real refusals lost.**
  Every converted pin fires the identical diagnostic under `.k`; the
  facet was incidental in all but one. `140_029_dup_tor_across_facets_
  refused` stays `.kz` — the pin *is* cross-facet duplication.
- **Coordinate drift is not a verdict.** `expected_patterns.txt` /
  `expected_error.txt` entries that pin `input\.kz` or absolute line
  numbers fail on a converted file with the *same* refusal — refresh
  the coordinate (`210_014`: same KORU021, filename moved), keep the pin.
  In `ERROR_AT`-pinned dirs every line before the refusal is
  position-load-bearing — do not drop residue there (`210_305`).
- **A red pin stays red under conversion.** `335_056` pins the
  `std/io:free` diagnostic spelling normalization still hasn't landed;
  `.k` preserves its redness exactly. Redness is the test's state, not
  the facet's.
- **Allow entries now beat dir heuristics.** `exempted()` returned
  "sibling MUST_ERROR" before reading the allow file, so an error-dir
  keep could never record a verdict — reordered; recorded rulings
  dispose.
- **The ambient host-const trap** (`near-pure`): a stray `const std =
  @import("std")` can be load-bearing even when nothing in the file
  references it — emitted Zig resolves `std.` names against verbatim
  host lines (`220_036` failed `backend-exec` the moment it was
  dropped). Residue is only residue after checking what the *emitter*
  produces.
- **Empty status meant `unparseable`, not `near-pure`.** 14 files whose
  koruc output was empty (stderr parse failures) fell through the
  manifest's status match into the judgment lane; fixed — they now
  count as `unparseable` where they belong.
- **Board at close:** convert-test 0, convert-other 0,
  error-pin-review 0, near-pure 32 (all keep-`.kz` verdicts — real
  host items, per-file verified), exempt 37.

## The contestant recipe

    python3 scripts/kz_sweep_manifest.py --lane <lane> --slice <i> --of <n>

Take a deterministic slice of one lane. For each file:

**convert-test** — `koruc input.kz to-k && rm input.kz`, then
`./run_regression.sh <full_test_name>`. Green = done. A rename is the whole
diff; nothing else changes. Commit slices, not one file at a time.

**convert-other** — same convert+remove, then `koruc <new>.k -c` for a
shape-check, and for `koru_std/` modules compile a consumer that imports the
module. Watch for same-stem siblings and for anything that globs `*.kz`
explicitly.

**error-pin-review** — read the pin first. Tests like
`100_084` (bare-Koru-line-parses-as-host_line) and `210_312_…_eats_next_decl_kz`
exist *because* the file is `.kz` — converting them would make them test
nothing. Convert only when the facet is incidental AND the same refusal
still fires afterward; otherwise leave it, and if the reason is portable add
a `path | reason` line to `invariants/checks/kz-preference.allow`.

**near-pure** — the gradient. One stray host line is usually a leftover
import or a debug line: drop it, the file becomes convertible, done. But
`koru_std/array.kz`'s single `const std = @import("std")` is load-bearing —
it is what `std.mem.sort` resolves to inside the `~define` bodies. Leave it
`.kz`, and a comment saying why earns its keep for the next reader.

## The judgment rules, compressed

- The gate holds the *strict* class (zero host items) forever — you are only
  deciding the 118 judgment rows and doing the 55 mechanical conversions.
- A conversion that makes a pin vacuous is worse than a convertible `.kz` —
  when in doubt, `exempt` with a reason beats `convert`.
- Never batch `rm` across files you haven't individually verified — the
  checkCompile-only path will not catch a consumer that breaks.

## Done-gates

1. `kz_sweep_manifest.py --lane convert-test` and `--lane convert-other`
   report zero rows on the regenerated manifest.
2. Every `error-pin-review` / `near-pure` row has a verdict: converted,
   allow-listed with a reason, or commented.
3. `zig build test` clean; the touched tests re-run green.
4. The gate row `kz-extension-is-earned` stays green throughout — it already
   is, since conversions remove `.kz` files rather than add them.
