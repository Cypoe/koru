---
type: belief
id: frag-the-target-features-are-a-guess-the-auxv-is-the-truth
provenance: 2026-10-12 — the PMULL CRC arm compiled to nothing in every docker-aarch64 build because builtin.cpu.features reported aes=false on silicon whose kernel auxv carried AES+PMULL (hwcap=0xefb3ffff). The instruction existed; the gate's oracle lied.
ts: 2026-10-12
---

`builtin.cpu.features` is a *guess about the build machine*, not a fact
about the running machine — and on the path that matters most (hardware
acceleration) it fails silently in exactly the environments where
correctness-by-detection is hardest to notice: VMs and containers.

Measured in the docker-aarch64 work container: `/proc/cpuinfo` and
`getauxval(AT_HWCAP)` both reported AES+PMULL (hwcap=0xefb3ffff) while
`builtin.cpu.features` answered aes=false. Every build in that environment
— `zig run`, `koruc build`, `zig build` native — compiled the table-walk
CRC at 0.44µs/KB while the PMULL fold sat unassembled behind a
comptime-true gate that was comptime false. The per-call cost of the lie
was ~3.7µs on an 8.9KB body, discovered only because a phase instrument
broke the compressor down and the CRC number didn't match the expected
hardware speed.

The rule has two halves. Detection: when the kernel is present, the auxv
is the oracle that cannot lie about running silicon — read it at runtime
(`getauxval(AT_HWCAP)` & HWCAP_AES|HWCAP_PMULL) rather than trusting the
target the compiler was told about; a container `var` can't hold the
answer (initializers are comptime), so lazily-populate a tri-state
atomic. Each platform arm is that platform's oracle — kernel-less targets
declare features at compile time because no kernel exists to ask.
Assembly: a runtime-gated instruction must still *assemble* for targets
that don't claim the feature — LLVM's integrated assembler honors
`.arch_extension` inside the asm block, which enables the mnemonic
without touching the target's codegen. The instruction then exists in the
binary everywhere and executes only where the kernel says it can.

Comptime feature gates remain correct for what they actually decide —
"does this spelling exist in the grammar for this target" — but the
moment a gate stands in for "does the running machine have the unit," it
has been promoted past its evidence, and the failure mode is silent:
everything works, just slower, forever.

x86 sharpens the same ruling: there is no auxv to ask — `AT_HWCAP` on
that arch is nearly empty — so the oracle is `CPUID.01H:ECX[1]`, read
directly. Unprivileged everywhere, honest everywhere, no OS arm needed.
And the fold itself turned out to be arch-neutral: the PCLMULQDQ port is
the same Gopal/Ozturk scheme with three immediates swapped for three
mnemonics — `ffCrcFold(lo, hi, o1)` takes the multiplies as comptime
parameters, so the bodies aarch64 and x86_64 share one proof instead of
two drifting copies. Verified on qemu-x86_64 (gate=PCLMUL, fold==table
at every bulk size 64..8992); Rosetta's ELF loader refuses Zig's segment
layout (`bss_size overflow`), so the execution oracle was qemu's TCG,
not the translator.

## Related

frag-the-assembly-grammar-decides-which-hardware-exists.md
frag-apple-silicon-cpu-clock-lives-in-pmgr.md
frag-an-oracle-that-samples-cannot-disagree.md
