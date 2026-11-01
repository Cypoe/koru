# 016 — std/num vs bc vs python decimal

Measured 2026-10-31 on `quantity-numbers` (WSL Ubuntu 20.04, x86_64,
glibc-2.31 shim). Rig: `run.sh` — same operands, same significant-digit
targets, three implementations. `koru kara` is `num.kz` with the limb-level
Karatsuba mul (KARA_MIN=24) + binary pow10/biPowFast, landed after the
schoolbook baseline below. `koru div` adds the own division layer
(divFast: custom schoolbook `divSB` everywhere + staged Newton reciprocal
`recipL` gated above NEWTON_MIN=512 divisor limbs).

## Time (ms)

| # | workload | koru Debug (schoolbook) | koru RF (schoolbook) | koru RF (kara) | koru RF (div) | koru RF (radix) | bc -l | py dec | py int |
|---|----------|--------------------:|---------------------:|---------------:|--------------:|------:|-------:|-------:|
| w1 | mul 2000d×2000d | 72.0 | 3.9 | **4.5** | **4.1** | **0.45** | ~2 | 0.13 | 0.10 |
| w2 | 3^100000 | 4000.9 | 305.7 | **315.7** | **306.1** | **55.1** | 110 | 0.50 | 1.02 |
| w3 | div →3000d | 74.5 | 3.6 | **3.5** | **3.4** | **0.65** | 20 | 0.13 | — |
| w4 | sqrt(2) →3000d | 93.9 | 3.4 | **2.0** | **1.7** | **0.60** | 130 | 2.32 | 0.26* |
| w5 | exp(1) →2000d | 5138.8 | 136.1 | **15.5** | **17.4** | **19.4** | 2210 | 3.14† | — |
| w6 | ln(2) →2000d | 17220.2 | 468.4 | **49.9** | **56.5** | **59.1** | 990 | 104.3† | — |
| w7 | sin(1) →2000d | 3875.9 | 102.6 | **18.6** | **23.2** | **24.4** | 1680 | 1.49† | — |
| w8 | π Machin →2000d | 8788.6 | 236.6 | **33.0** | **34.2** | **39.0** | 480 | 25.1† | — |
| w9 | mod | 99.6 | 5.6 | **5.6** | **5.5** | **0.44** | 20 | — | 0.14 |
| w10 | 2^0.5 powf →2000d | 23535.5 | 602.6 | **72.5** | **74.3** | **82.4** | 3260 | 138.2† | — |

\* `math.isqrt` oracle. † py3.8 decimal lacks exp/ln/sin/atan — Taylor
scripts in `bench.py` over the C core. bc times include ~2ms proc floor.

## Correctness — digit agreement (common prefix, digits)

| # | koru=bc | koru=py | bc=py | verdict |
|---|--------:|--------:|------:|---------|
| w1 | 3998 | 3998 | 3999 | exact mul, full agreement to last digit |
| w2 | 47713 | 47713 (int) | — | exact pow, all 47713 digits identical |
| w3 | 2998 | 2998 | 3000 | boundary rounding only |
| w4 | 3001 | 3001 | 3001 | full; also exact vs `isqrt` oracle (3001) |
| w5–w8 | 1999–2021 | 1999–2019 | 1999–2020 | ±1 boundary digit on 2000-digit targets |
| w9 | 997 | 997 | 997 | exact mod, full agreement |
| w10 | 1999 | 1999 | 1999 | boundary digit |

Debug and ReleaseFast outputs are byte-identical.

## Reading it

- **Karatsuba moved the ceiling**: transcendentals dropped 5.6–9.4×
  (exp 136→15.5ms, ln 468→49.9ms, sin 103→18.6ms, Machin 237→33ms,
  powf 603→72.5ms). The limb layer is ours — `mulL`/`addL`/`subL`/
  `addInto` over `[]Limb`, arena-scratch recursion, sign propagated at
  the boundary (a signed-magnitude `Managed` is *not* a nonnegative one —
  alternating series caught that once).
- **vs bc**: koru wins all 10. w2 fell last — not to better
  arithmetic but to killing the *conversion* tax: Zig's `setString`/
  `toString` are per-digit quadratic (measured 231ms + 35ms on the
  47713-digit operand — 90% of w2). Replaced both directions with
  divide-and-conquer: digits->limbs splits at the midpoint
  (val(hi)*10^lo + val(lo)), limbs->digits splits by 10^(nd/2) through
  `divAnyL` — the conversion layer dogfoods the owned division too.
  Schoolbook base case chunks 19 digits per limb step under
  RADIX_DNC_MIN=600. Every workload routes through it: w2 297->55ms,
  w1 3.7->0.45ms, w3 3.0->0.65ms, w4 1.7->0.60ms, w9 7.3->0.44ms.
- **own division is in**: `decDiv`/`decMod` no longer call
  `Managed.divTrunc` — `divFast` runs our schoolbook `divSB` (per-limb
  u128 trial + two-limb-warmup correction) and, past NEWTON_MIN=512
  divisor limbs with quotient >=3x the divisor, a staged Newton
  reciprocal (`recipL`, floor(beta^3n/B) by doubling-size stages).
  Limb-level, divSB beats `Managed.divTrunc` below ~200 limbs
  (16us vs 34us at 104/73) and runs ~1.6x at 3000/1200. The Newton arm
  is *proven but gated*: measured, a full-product reciprocal costs
  ~4-14 muls at ~5n limbs and loses to schoolbook at every size we
  exercise — it engages only where the quotient amortizes it. The
  named ceiling is short products (top-limb-only B*R^2 per iteration),
  which is what GMP pays for before Newton wins.
- **division proven**: quotient/remainder identity `q*b+r = a` plus
  remainder bounds on 3000 randomized operand shapes (30-1100 digits,
  straddling the old Newton gate), vs a corrected Python oracle —
  earlier drafts of that oracle compared real quotients against
  integer `//` and mis-flagged; the genuine diff is zero.
- **a real divSB bug found by the isqrt work**: Knuth-D qhat clamp
  produced `rhat >= beta`, then `(rhat << 64)` wrapped u128 (Zig `<<`
  truncates silently) -> qhat came out one too small whenever the
  raw estimate hit `qhat0 >= beta` (u[j+n] == v[n-1] exactly — the
  beta-1 quotient-limb shape random fuzzing essentially never makes).
  Fixed to canonical D3 form: clamp folded into the loop, `rhat < beta`
  guards the comparison. Now proven additionally on 1000 adversarial
  constructed quotients (runs of beta-1 digits, trailing-zero divisor
  limbs) — the shape that caught it, 0 failures.
- **own isqrt is in**: `decSqrt`/`fxSqrt` no longer call
  `Managed.sqrt` — `sqrtFast` runs `isqrtL`, recursive-seed Newton
  (isqrt of the top half, shifted (dropped limbs)*32 bits, a strict
  overestimate) descending monotonically on `divAnyL` — it dogfoods
  the owned division layer, needs no normalization preconditions, and
  converges in ~log iterations with a <=4-step bounded fixup.
  w4 sqrt: 1.74ms RF (was ~1.7 on Managed.sqrt — correctness was the
  point, not speed). Proven on 2500 randomized operand shapes
  (10-5777 digits, incl. ~3000-digit squares and unnormalized tops)
  vs `math.isqrt` — exact, zero failures.
- **vs C decimal/int**: python still wins exact ops — but `ln` (49.9 vs
  104ms) and `powf` (72.5 vs 138ms) now beat the python-Taylor arms:
  a compiled-Karatsuba inner loop outruns interpreted Taylor over a
  faster limb library.
- **Correctness gate**: 615 = 44/44, 017 qcalc race = 0/20000
  mismatches, limb layer proven against `Managed.mul` on 2800
  randomized operand shapes, `divAnyL` on 3000 mixed + 1000
  adversarial (beta-1 quotient limbs), `isqrtL` on 2500, digit
  agreement unchanged (all 47713 of 3^100000, all 3001 of sqrt2).

## Independent oracle — SymPy 1.14 + mpmath 1.4 (via nix)

`run_oracle.sh` runs `sympy_oracle.py`, a checker that shares no code with
koru, bc, or decimal. Two layers, measured 2026-10-31 on `koru.out`:

**Layer A — digits.** mpmath at mp.dps=3100 recomputes every workload;
koru's emitted digits are compared as strings (exact ops against exact
integer references, no float proxy):

| # | result |
|---|--------|
| w1 | 3999/3999 digits — exact |
| w2 | 47713/47713 digits — exact |
| w3 | 2998/2998 emitted digits correct |
| w4 | 3001/3001 emitted digits correct |
| w5–w7, w10 | all emitted digits correct (2000/2000, 1998/1998) |
| w8 | 2019/2023 — last 4 digits differ (Machin rounding accumulation at the boundary, consistent with the bc/decimal comparison) |
| w9 | 997/997 digits — exact |

Speed note, stated because it is true: mpmath computes all five
transcendentals in ~8 ms total — AGM-class algorithms, not Taylor series.
That gap is algorithmic and is the next ceiling after Newton-division.

**Layer B — certificates.** SymPy independently verifies what koru emits:

- All 12 recorded ODE certificates annihilate their functions — residual
  symbolically 0 (exp self-law, shifted integral forms, sqrt/quartic
  algebraic laws, inv, sum/product closures, `xf'−f=0` for x).
- All 3 recorded recurrences hold on true series coefficients (exp,
  sqrt(1+x), 1/(1−x)).
- The `cser` coefficient tail for √(1+x) matches sympy's series exactly:
  `[1, 1/2, -1/8, 1/16, -5/128, 7/256]`.
- The rel-layer conservation check `D(sin²+cos²)` reduces to 0 under
  sympy's own differentiation.
- `dsolve(y''=xy)` returns Airy functions — consistent with koru's
  `non-Liouvillian` classification, not a contradiction of it.

SageMath was not run; SymPy+mpmath covered the comparison surface.

## Reproduce

    ./run.sh            # needs bc, python3, koruc, zig on PATH
    ./run_oracle.sh     # needs sympy+mpmath (nix store paths self-discovered)
