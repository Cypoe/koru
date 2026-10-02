#!/usr/bin/env python3
"""holonomic_synth.py — certified program synthesis over Koru fold updates.

The GA's genome is the arithmetic update expression of a canonical
`#L`/`@L` fold — candidates are born inside the holonomic gate's fragment
by construction, so the gate is the fitness oracle, not a post-hoc check:

    fitness  = first-divergence index into the 64-iterate window
               (semantic: how far the trajectory agrees with the target)
    terminal = gate verdict EQUAL — program + certificate, not + hope

Random mutation alone found 0/300 hits on squares; directed search is
the whole point. Usage:

    python scripts/holonomic_synth.py --target fuzz/holonomic/sq_direct.k
    python scripts/holonomic_synth.py --selftest
"""
import argparse
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import holonomic_gate as hg

TPL = """tor step {{ n: i64, acc: i64 }}
| more {{ n: i64, acc: i64 }}
| done i64

step = if(n < 20)
| then => more {{ n: n + 1, acc: {e} }}
| else => done acc

run = #L step(n: 1, acc: 0)
| more s |> @L(s.n, s.acc)
| done e -> e
"""

LEAVES = ["n", "acc", "1", "2", "-1"]
OPS = "+-*"
WINDOW = 64


# ---------------------------------------------------------------- genome

def gen_tree(rng, depth=0):
    if depth > 2 or rng.random() < 0.35:
        return rng.choice(LEAVES)
    return (rng.choice(OPS), gen_tree(rng, depth + 1), gen_tree(rng, depth + 1))


def render(t):
    if isinstance(t, str):
        return t
    op, a, b = t
    return f"({render(a)} {op} {render(b)})"


def _subtrees(t, acc):
    acc.append(t)
    if isinstance(t, tuple):
        _subtrees(t[1], acc)
        _subtrees(t[2], acc)
    return acc


def _replace(t, old, new):
    if t is old or t == old:
        return new
    if isinstance(t, tuple):
        return (t[0], _replace(t[1], old, new), _replace(t[2], old, new))
    return t


def mutate(rng, t):
    subs = _subtrees(t, [])
    site = rng.choice(subs)
    return _replace(t, site, gen_tree(rng))


def crossover(rng, a, b):
    sa, sb = _subtrees(a, []), _subtrees(b, [])
    return _replace(a, rng.choice(sa), rng.choice(sb))


# ---------------------------------------------------------------- fitness

def _trajectory_of(expr_src):
    fold = hg.extract_fold(TPL.format(e=expr_src))
    return hg.trajectory(fold, WINDOW, bounded=False)


def divergence_index(candidate_seq, target_seq):
    """First index where the trajectories disagree, or len if the whole
    window agrees. Semantic fitness: agreement depth, not syntax."""
    for i, (a, b) in enumerate(zip(candidate_seq, target_seq)):
        if a != b:
            return i
    return min(len(candidate_seq), len(target_seq))


# ------------------------------------------------------------------- loop

def synthesize(target_src, pop=40, gens=25, seed=0, max_find=3,
               verbose=True):
    rng = random.Random(seed)
    target_fold = hg.extract_fold(target_src)
    target_seq = hg.trajectory(target_fold, WINDOW, bounded=False)

    population = [gen_tree(rng) for _ in range(pop)]
    found = []
    seen = set()
    for g in range(gens):
        scored = []
        for t in population:
            expr = render(t)
            try:
                seq = _trajectory_of(expr)
            except hg.Refused:
                scored.append((0, t))
                continue
            scored.append((divergence_index(seq, target_seq), t))
        scored.sort(key=lambda s: -s[0])
        best = scored[0]
        if verbose:
            print(f"g{g:02d} best agreement {best[0]}/{len(target_seq)}"
                  f"  acc: {render(best[1])}")
        if best[0] >= len(target_seq):
            # every candidate whose whole window agrees gets certified —
            # the champion isn't the only member worth a certificate
            for _s, t in scored:
                if _s < len(target_seq):
                    break
                expr = render(t)
                if expr in seen:
                    continue
                seen.add(expr)
                verdict, why = hg.gate(target_src, TPL.format(e=expr))
                if verdict == "EQUAL":
                    found.append((expr, why))
                    if verbose:
                        print(f"  EQUAL {expr}")
                    if len(found) >= max_find:
                        return found
        # selection: elites + tournament offspring
        elites = [t for _s, t in scored[:max(2, pop // 8)]]
        nxt = list(elites)
        n_imm = max(1, pop // 4)              # keep diversity alive
        nxt += [gen_tree(rng) for _ in range(n_imm)]
        while len(nxt) < pop:
            a = rng.choice(scored[:pop // 2])[1]
            b = rng.choice(scored[:pop // 2])[1]
            child = crossover(rng, a, b)
            if rng.random() < 0.4:
                child = mutate(rng, child)
            nxt.append(child)
        population = nxt
    return found


def selftest():
    target = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "..", "fuzz", "holonomic", "sq_direct.k")
    src = open(target, encoding="utf-8").read()
    found = synthesize(src, pop=60, gens=30, seed=3, max_find=3,
                       verbose=True)
    ok = len(found) > 0
    print(f"{'PASS' if ok else 'FAIL'}: {len(found)} certified-equal "
          "mutant(s) synthesized")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", default=None)
    ap.add_argument("--pop", type=int, default=40)
    ap.add_argument("--gens", type=int, default=25)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if not args.target:
        ap.error("--target required (or --selftest)")
    src = open(args.target, encoding="utf-8").read()
    found = synthesize(src, args.pop, args.gens, args.seed)
    for expr, why in found:
        print(f"\nCERTIFIED mutant: acc: {expr}\n  {why}")
    return 0 if found else 2


if __name__ == "__main__":
    sys.exit(main())
