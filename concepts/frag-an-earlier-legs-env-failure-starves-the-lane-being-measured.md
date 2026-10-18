---
type: belief
id: frag-an-earlier-legs-env-failure-starves-the-lane-being-measured
provenance: 2026-10-18 — the K1 c-leg corpus ran in WSL and reported 77 red;
  68 of them were `cs-compile` because dotnet was absent on that host. The `c`
  leg never ran for any of them: the harness's equivalence legs are sequenced
  (js → cs → c) and each self-gates on `SUCCESS`, which the failing leg had
  already removed. The report named the leg that failed, not the leg that was
  never asked. With dotnet + node provisioned the same 77 went 77/77 green.
ts: 2026-10-18
---

# An earlier leg's env failure starves the lane being measured (belief)

A multi-lane harness that sequences its legs under one `SUCCESS` marker has a
quiet reporting property: a failure in leg *n* masks the verdicts of every leg
after it. The test goes red, the FAILURE file names the leg that failed, and
nothing records whether the later lanes were equivalent, refused, or simply
**unasked**.

Measured on the K1 ccomp lane: 68 of 77 WSL reds were `cs-compile` — a missing
`dotnet`, an environment gap in a lane orthogonal to the one under measurement.
For every one of those tests the emitted-C/ccomp verdict did not exist; the
suite's own self-gating ("no SUCCESS → immediate no-op") is what made the starve
correct *by design*: a failed test must not keep producing artifacts. The design
is right — a broken leg should not spawn more. What it costs is that **the red
count over-describes the language legs and under-describes the lane state**: 68
`cs-compile` reds said nothing about whether `c` was healthy.

## What follows

- **Triage by leg, not by count.** A `cs-compile` red on a host without dotnet
  is `c: unmeasured`, not `c: broken` and not `c: green`. The verdict you want
  may be behind the red, never executed. Provision the earlier legs (or accept
  the starvation as a named lane boundary) before reading the later lane's
  state out of the failure list.
- **The lane contract is part of the artifact.** The provisioned invocation —
  `DOTNET_ROOT` over the nix profile, `KORU_BACKEND_TARGET=x86_64-linux-musl`
  on a glibc-2.31 host — now lives in `scripts/cc_gates.sh`'s header because it
  *is* the reproduction recipe: without it, the battery's own report is
  ambiguous about which lane failed.
- **This is the pin-read frag's sibling, one level up.** `frag-a-pin-file-read
  -raw-measures-the-checkout` is about bytes reaching the compiler mangled;
  this is about verdicts never being produced at all. Both are the same posture:
  read what the harness actually executed, not what the failure labels imply it
  covered.

## Open

- Whether legs should record a per-lane verdict even under starve (`c: starved`
  vs absent) is a harness-shape call for Lars — the TARGETS.json upsert
  already has the row structure to carry it.
