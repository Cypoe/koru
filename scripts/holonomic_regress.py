#!/usr/bin/env python3
"""holonomic_regress.py — certified symbolic regression over fold genomes.

holonomic_synth.py searches for a fold *equivalent to a reference program*.
This is the regression dual: the target is bare sequence data — observed
iterates, no program — and the deliverable is a fold whose certified
trajectory extends the observations:

    fitness  = first-divergence index into the W observed terms
               (semantic: agreement depth against data, not syntax)
    terminal = REGRESSED — candidate's trajectory reproduces all W terms
               AND the candidate carries a gate-verified certificate
               (order m, method). The certificate is a theorem about the
               program; the data fit is regression — finite observations
               admit infinitely many extensions, so the honest claim is
               "this program provably generates a sequence whose first W
               terms are the data", never "the data are this sequence".

    overdetermination = W - m: how much of the data went past the
    certificate's freedom. A match with W >> m is a stronger signal than
    one barely over the order — reported, not hidden.

The genome is the same update-expression space as holonomic_synth —
candidates are born inside the gate's fragment, so certification needs
no adapter. Usage:

    python scripts/holonomic_regress.py --seq "1,4,9,16,25,36,49,64"
    python scripts/holonomic_regress.py --seq-file seq.txt --emit out.k
    python scripts/holonomic_regress.py --selftest
"""
import argparse
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import holonomic_gate as hg
from holonomic_synth import (TPL, LEAVES, OPS, WINDOW, gen_tree, render,
                             mutate, crossover, divergence_index)


def parse_seq(text):
    return [int(x) for x in text.replace("\n", ",").split(",") if x.strip()]


def regress(data, pop=40, gens=25, seed=0, max_find=3, verbose=True):
    """GA over update genomes; fitness = agreement depth with `data`."""
    rng = random.Random(seed)
    W = len(data)
    population = [gen_tree(rng) for _ in range(pop)]
    found = []
    seen = set()
    for g in range(gens):
        scored = []
        for t in population:
            expr = render(t)
            try:
                fold = hg.extract_fold(TPL.format(e=expr))
                seq = hg.trajectory(fold, W, bounded=False)
            except hg.Refused:
                scored.append((0, t))
                continue
            scored.append((divergence_index(seq, data), t))
        scored.sort(key=lambda s: -s[0])
        best = scored[0]
        if verbose:
            print(f"g{g:02d} best agreement {best[0]}/{W}"
                  f"  acc: {render(best[1])}")
        if best[0] >= W:
            # every candidate matching the whole window earns a certificate
            for _s, t in scored:
                if _s < W:
                    break
                expr = render(t)
                if expr in seen:
                    continue
                seen.add(expr)
                fold = hg.extract_fold(TPL.format(e=expr))
                order, polys_or_seq, method_or_saw = hg.certify(
                    fold, window=max(W, WINDOW))
                if order is None:
                    if verbose:
                        print(f"  CANDIDATE {expr} — fits window, "
                              "no verified certificate")
                    continue
                order_m, polys, method = order, polys_or_seq, method_or_saw
                found.append((expr, order_m, polys, method))
                if verbose:
                    print(f"  REGRESSED {expr}  "
                          f"(order {order_m}, {method}, W={W})")
                if len(found) >= max_find:
                    return found
        elites = [t for _s, t in scored[:max(2, pop // 8)]]
        nxt = list(elites)
        nxt += [gen_tree(rng) for _ in range(max(1, pop // 4))]
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
    here = os.path.dirname(os.path.abspath(__file__))
    # a_0 is the first post-update value: squares (n+1)^2 -> 1,4,9,...
    squares = [k * k for k in range(1, 33)]
    found = regress(squares, pop=60, gens=30, seed=3, max_find=3)
    ok = len(found) > 0
    print(f"{'PASS' if ok else 'FAIL'}: squares data -> {len(found)} "
          "certified program(s)")
    # negative control: fibonacci needs two carried fields — a single
    # acc update over (n, acc) cannot express it; honest no-match
    fib = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610]
    found_fib = regress(fib, pop=40, gens=15, seed=1, max_find=1,
                        verbose=False)
    ok2 = len(found_fib) == 0
    print(f"{'PASS' if ok2 else 'FAIL'}: fib data -> "
          f"{len(found_fib)} match(es) (want 0 — unreachable in fragment)")
    return 0 if ok and ok2 else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seq", default=None, help="comma-separated iterates")
    ap.add_argument("--seq-file", default=None)
    ap.add_argument("--emit", default=None, help="write first match .k here")
    ap.add_argument("--pop", type=int, default=40)
    ap.add_argument("--gens", type=int, default=25)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if args.seq:
        data = parse_seq(args.seq)
    elif args.seq_file:
        data = parse_seq(open(args.seq_file, encoding="utf-8").read())
    else:
        ap.error("--seq or --seq-file required (or --selftest)")
    found = regress(data, args.pop, args.gens, args.seed)
    for i, (expr, order, polys, method) in enumerate(found):
        print(f"\nREGRESSED #{i}: acc: {expr}")
        print(f"  certificate (order {order}, {method}): "
              f"{hg.cert_str(order, polys)}")
        print(f"  overdetermination: W={len(data)} - m={order} "
              f"= {len(data) - order}")
    if found and args.emit:
        with open(args.emit, "w", encoding="utf-8") as f:
            f.write(TPL.format(e=found[0][0]))
        print(f"\nwrote {args.emit}")
    return 0 if found else 2


if __name__ == "__main__":
    sys.exit(main())
