---
type: belief
id: frag-zig-is-three-jobs-syscalls-are-smallest
provenance: design session with Lars, 2026-10-12 — "what would it take to
  bypass Zig for side effects and just use syscalls." Measured the tree
  (HEAD cea2700c0) before answering; the stratification below is the
  instrument reading, not a reading of the code.
ts: 2026-10-12
---

# Zig carries three jobs in the pipeline; the syscall surface is the smallest (belief)

The proposal was "emit syscalls instead of Zig for side effects." The
measurement: 250 `|zig` proc bodies in `koru_std/`, 17,165 lines of Zig text,
and they stratify into three loads that have almost nothing to do with each
other:

- **~76% of the lines (56 bodies, 13,008) are the compiler itself.** Transforms
  taking `*const std/compiler:Item`, `Program`, `ErrorReporter`; walking AST;
  returning `SiteResult`. They run inside the stage-C backend and never appear
  in an emitted user binary. Lifting them is the self-hosting project, not an
  emission decision — gated on Koru owning its compiler types natively.
- **~14% (158 bodies, 2,352 lines) are runtime/data.** Store internals, field
  strike, formatting — where Zig is functioning as a *portable vectorizer and
  raw-memory dialect*, not an OS interface. `std/field:strike` is the exhibit:
  114 lines, zero syscalls, `sliceAsBytes`, `@Vector(4,u64)`, hand-tuned against
  LLVM with measured wins cited in its own comments. Lifting this class needs
  language surface Koru doesn't have: mutable indexed byte memory, vector
  types, casts, allocation ownership.
- **~11% (36 bodies, 1,805 lines) are OS-effect marshaling.** The entire real
  syscall vocabulary of the stdlib: ~30 syscalls in ~12 families (write, read,
  openat/close, exit, mmap/munmap/mprotect, clock_gettime/nanosleep,
  clone/futex, socket family, fork/exec/wait, getrandom). argv/envp aren't
  syscalls at all — they're entry-stack data, which is why a `_start` stub is
  part of any true bypass.

## The three layers are different questions wearing one word

"Zig" in this repo means: the **backend compiler** (needs a whole OS — reads
`koru_std/` off disk, `Child.run`s `zig build`; stays fat indefinitely), the
**emitted code** (generated; no human writes it — the only layer where a
syscall could ever appear), and the **user-facing source** (already pure;
nothing in a `.k` flow names a mechanism — the "no annotation" property the
question wanted already holds there). Because the emitted layer is generated,
"syscall-level" is an *emitter decision*, not a port and not a language
feature. That is what makes it simultaneously cheap and shallow.

## What is and isn't true about hello world today

Verified by building and reading `output_emitted.zig` (7,508 B): the program's
whole OS surface is `posix.write`, the allocator backing, `debug.print` +
`process.exit` in the leak check, and the panic handler. On Linux,
`std.posix.write` already lowers to a bare `syscall` instruction — no libc in
between. On Darwin, `emit_build_zig` linkLibC's every non-wasm target, so the
syscall is reached *through* libSystem — and threads/spawn have no stable
raw-syscall path on macOS at all (pthread_create/posix_spawn are library
calls). **A pure-syscall binary is a Linux/freestanding reality, not a Darwin
one.** The raw-path precedent exists and is pinned: `print.blk|raw_posix`
(320_100) emits an inline `posix.write` + hand-coded digit writer, routed
per-OS by `[build]std/build:variants` — the mechanism works; what's missing is
only breadth (~45 bodies would need bodies of this kind).

## The ruling this produces

The honest price of "hello world lowers to raw syscalls" is four sites and a
`_start` — an afternoon. The honest price of "user programs in pure Koru" is
the 14% plus a **raw-memory dialect** (a Lars decision — no spellings exist for
`arr[i] |=`, byte views, vector ops) plus an **LLVM-grade emitter**, because
the tuned bodies regress ~7x under a naive backend. The `|mlir` variant tests
(8209/8210: `scf.for` + `iter_args` lowered AOT) are the embryonic honest form
of that — LLVM without Zig source — and the thing worth growing if this
direction ever becomes real.

Two corollaries worth keeping separate:

- The *semantic* payoff people reach for when they say "syscalls" — errno as a
  named branch set the checker can see, derived purity instead of
  `~[pure]`-annotation trust, the program's terminal branch as its exit status
  (today `pub fn main() void` evaporates every branch outcome at the process
  boundary) — does **not** require raw syscalls. It requires the marshaling to
  be legible to Koru, which the emitter could do while still writing Zig.
  Variant-picked bodies (`|raw_posix`) answer "which implementation"; a
  denotation answers "what does this tor mean on this platform." If the
  semantic version ever happens, the second is the right shape.
- The effect bodies are **two-way**: `read-lines`'s Zig calls `line(l)` back
  into the flow's continuation. The architecture is already Koru-ocean with
  Zig islands, not a Zig program with Koru calls; lifting moves the shoreline
  rather than building the bridge.

## Would falsify this

- Koru grows a raw-memory dialect, or `strike`-class bodies become expressible
  — the 14% stops being a language gap and the calculus reopens.
- An MLIR/LLVM backend lands for real — then "bypass Zig" stops meaning "lose
  the optimizer."
- A recount of the 250 bodies that materially disagrees with 76/14/11.
- macOS stabilizes a raw syscall ABI (do not hold breath).

Related: [[frag-naive-koru-lands-where-expert-zig-lands]] (what LLVM is doing
for the emitted code — the load a native emitter must carry),
[[frag-self-hosting-pins-a-pass-to-its-bootstrap-stage]] (why the 76% can't
just be "moved"),
[[frag-a-reference-emitters-shape-is-an-accident-of-its-host]] (port semantics,
not shape — same doctrine at the emitter layer),
[[frag-tilde-marks-the-host-boundary]] (the `|zig` body as escape hatch),
[[frag-a-cost-the-optimizer-deletes-was-never-there]] (the measured-not-reasoned
stance the performance half of this inherits).
