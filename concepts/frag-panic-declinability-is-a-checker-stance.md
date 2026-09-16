---
type: belief
id: frag-panic-declinability-is-a-checker-stance
provenance: korulang_org session drafting "The Call Site Is the Match", 2026-09-16 — Lars ruled while reviewing the branch-kind section: keep `?!` as the only panic marker and let `--panic-branches=strict` carry "forced", rather than grow a `| !` spelling
ts: 2026-09-16
---

# Panic declinability is a checker stance, not a branch kind (belief)

The branch kind-space is two sides by three kinds: `|`/`!` (outcome vs
effect) × required / `?` optional / `?!` panic. `?!` is one marker on
whichever side it rides — the 210_126 pin exists precisely to keep it from
reading as `?` optional + `!` effect.

**The ruling (Lars, 2026-09-16): there is no `| !` spelling and there should
not be.** "A panic the caller may not decline" is not a fourth kind of
outcome — it is a stance the checker takes over the program, and a flag is
the right granularity for that stance: `--panic-branches=strict` turns every
unhandled `?!` into KORU022 (the 210_130 pin). Declinability is a property
of the audit, not of the protocol.

## Why it lands there and not in the grammar

A per-branch forcing granularity already exists at both ends of the lever:
per branch, forced is a required branch plus a written arm — the caller who
must not skip is exactly the caller exhaustiveness already compels;
program-wide, forced is the flag. A `| !` marker would fork the kind-space
to four to express a meaning that lives one layer up — *who is allowed to
decline* — which is checker policy, not outcome shape. Keep the kind-space
closed at 2×3; the audit layer owns the forcing.

## What would make this wrong

A case where per-branch non-declinability is genuinely load-bearing — one
tor whose panic must never be rescued while a sibling's `?!` stays
declinable, in a program the flag cannot be scoped for. If that shape shows
up, `| !` (or a per-branch forced marker) becomes the missing spelling and
this belief wants `correct`, not a quiet workaround. Until then this is the
standing refusal, and it is the same refusal the corpus already holds
elsewhere: variance that belongs to the checker does not get a keyword.

Relates to [[frag-effect-continuation-marker-kinds]] (the `!`/`|` side axis
this ruling crosses — the kind-space is closed on BOTH axes) and
[[frag-a-synthesized-safety-arm-only-exists-where-the-pass-looked]] (what
declining a `?!` means mechanically — the arm is synthesized, not skipped).
