#!/usr/bin/env python3
"""Genetic composition fuzzer for koru (challenge 007, mechanized).

The fitness map IS the census: a program scores for every *uncovered*
construct-under-context cell it hits (cells the regression corpus never
nested — see composition_census.py). Selection pressure pushes the
population into the uncovered regions; `koruc -c` verdicts decide whether a
hit is a green composition (locks the interaction) or a rejection candidate
(red-pin material for the arbiters).

Genotype: a base carrier (corpus test text) + a list of splice edits.
Each edit: insert a harvested payload subtree (a real construct's lines,
verbatim from a corpus test) into a hole (an indented block body) of the
carrier or of an earlier payload.

Ploidy rules (keeps signal above noise):
  - payloads are harvested whole subtrees (line + deeper-indented block),
    never invented text
  - payloads that reference names they don't bind still splice — `koruc -c`
    is the validity gate; rejects are cheap (~0.2s) and score 0 anyway
  - verdict interestingness: PASS on uncovered cell > exotic reject > boring
    reject (unknown-name/missing-module class scores 0)

Usage:
  python3 scripts/composition_gp.py [--gens N] [--pop N] [--seed S]
                                    [--cluster SUBSTR] [--max-tests N]
                                    [--splice-budget N]   # edits per genome
"""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import subprocess
import sys
import time
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REG = os.path.join(ROOT, "tests", "regression")
SCRATCH = os.path.join(ROOT, ".kfuzz")
KORUC = os.environ.get("KORUC", os.path.join(ROOT, "zig-out", "bin", "koruc"))

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from composition_census import scan_file, CONSTRUCTS  # reuse detectors

REAL_CONTEXTS = {"capture", "for_each", "if_cond", "effect_arm", "branch_arm",
                 "pipeline", "record", "store", "glob"}

# ---------------------------------------------------------------------------
# corpus harvesting
# ---------------------------------------------------------------------------

def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip())


def harvest_payloads(paths):
    """(construct, subtree_text) — every maximal indented block headed by a
    construct line. Subtree = head line + all deeper-indented following lines."""
    payloads = []
    for p in paths:
        try:
            lines = open(p, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            continue
        for i, line in enumerate(lines):
            code = line.split("//")[0]
            if not code.strip():
                continue
            hits = [k for k, rx in CONSTRUCTS.items() if rx.search(code)]
            if not hits:
                continue
            ind = indent_of(line)
            j = i + 1
            while j < len(lines):
                l = lines[j]
                if l.strip() and indent_of(l) <= ind:
                    break
                j += 1
            subtree = "\n".join(lines[i:j])
            # cap payload size — splicing a whole test is a crossover, not a
            # mutation; small subtrees keep the genome legible
            if 1 <= j - i <= 12:
                # statement-level only: decls (import/pub/tor/const) and host
                # bodies (~, |zig) are file-top or .kz-only — inside a block
                # they are guaranteed-boring rejects, not compositions
                head = line.strip()
                if (head.startswith(("import ", "pub ", "tor ", "const", "~"))
                        or "|zig" in subtree):
                    continue
                for h in hits:
                    payloads.append((h, subtree))
    return payloads


def find_holes(lines):
    """Yield (line_idx, indent) — positions where a payload may be spliced:
    the end of each indented block body (before the indent drops back)."""
    holes = []
    for i, line in enumerate(lines):
        if not line.strip():
            continue
        ind = indent_of(line)
        nxt = lines[i + 1] if i + 1 < len(lines) else ""
        if nxt.strip() and indent_of(nxt) < ind and ind > 0:
            holes.append((i, ind))
    return holes


def hole_context(lines, hole_idx):
    """The construct that opened the block this hole lives in."""
    ind = indent_of(lines[hole_idx])
    for i in range(hole_idx - 1, -1, -1):
        if lines[i].strip() and indent_of(lines[i]) < ind:
            code = lines[i].split("//")[0]
            hits = [k for k, rx in CONSTRUCTS.items() if rx.search(code)]
            if hits:
                return hits[0], indent_of(lines[i])
            ind = indent_of(lines[i])
    return "top", 0


# ---------------------------------------------------------------------------
# genome
# ---------------------------------------------------------------------------

class Splice:
    __slots__ = ("carrier", "hole", "payload")

    def __init__(self, carrier, hole, payload):
        self.carrier = carrier      # path to input.k
        self.hole = hole            # (line_idx) in carrier — re-found at apply
        self.payload = payload      # (construct, subtree_text)

    def apply(self):
        lines = open(self.carrier, encoding="utf-8", errors="replace").read().splitlines()
        holes = find_holes(lines)
        if not holes:
            return None
        idx, ind = holes[self.hole % len(holes)]
        ctx, ctx_ind = hole_context(lines, idx)
        pay_lines = self.payload[1].splitlines()
        # reindent payload to sit at the body's indentation
        pay_ind = indent_of(pay_lines[0])
        body = "\n".join(
            " " * ind + l[pay_ind:] if l.strip() else ""
            for l in pay_lines
        )
        out = lines[: idx + 1] + [body] + lines[idx + 1:]
        return "\n".join(out) + "\n", ctx


def eval_genome(splices, uncovered, koruc_timeout=60):
    """Apply splices; returns (src_text|None, covered_cells, verdict, sig)."""
    if not splices:
        return None, set(), None, ""
    res = splices[0].apply()
    if res is None:
        return None, set(), None, ""
    src, ctx = res
    cells = {(splices[0].payload[0], ctx)}
    # nested splices apply onto the already-spliced text — for v1, evaluate
    # multi-splice genomes by applying remaining splices textually
    text_lines = src.splitlines()
    for sp in splices[1:]:
        holes = find_holes(text_lines)
        if not holes:
            break
        idx, ind = holes[sp.hole % len(holes)]
        ctx2, _ = hole_context(text_lines, idx)
        pay_lines = sp.payload[1].splitlines()
        pay_ind = indent_of(pay_lines[0])
        body = "\n".join(" " * ind + l[pay_ind:] if l.strip() else "" for l in pay_lines)
        text_lines = text_lines[: idx + 1] + [body] + text_lines[idx + 1:]
        cells.add((sp.payload[0], ctx2))
    src = "\n".join(text_lines) + "\n"
    uncovered_hits = {c for c in cells if c in uncovered}
    return src, uncovered_hits, cells, ""


def koruc_check_text(src: str, tag: str) -> tuple:
    path = os.path.join(SCRATCH, "gp", f"{tag}.k")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(src)
    try:
        r = subprocess.run([KORUC, "-c", path], cwd=ROOT,
                           capture_output=True, text=True, timeout=60)
        tail = (r.stderr or r.stdout or "").strip().splitlines()
        sig = tail[-1][:160] if tail else "<clean>"
        return r.returncode == 0, sig
    except subprocess.TimeoutExpired:
        return False, "TIMEOUT"


BORING = re.compile(r"KORU002|not found|undeclared|unknown|no member", re.I)


def fitness(uncovered_hits, all_hits, ok, sig, rarity):
    """Gradient toward the frontier: exact uncovered hits score big, but
    merely landing a frontier construct under a real context, or hitting a
    rare covered cell, still earns a slope to climb."""
    f = 0.0
    if uncovered_hits:
        f += 10.0 * len(uncovered_hits) + (5.0 if ok else (0.5 if BORING.search(sig) else 2.0))
    f += 1.0 * sum(1 for h in all_hits if h not in uncovered_hits and rarity.get(h, 99) <= 3)
    f += 0.2 * sum(1 for h in all_hits)          # any real nesting is something
    if ok:
        f += 0.5                                # compiles at all
    return f


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--gens", type=int, default=6)
    ap.add_argument("--pop", type=int, default=40)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--cluster", default=None)
    ap.add_argument("--max-tests", type=int, default=400)
    ap.add_argument("--splice-budget", type=int, default=2)
    args = ap.parse_args()

    rng = random.Random(args.seed)
    # positive tests only — a MUST_ERROR carrier is malformed by design, its
    # rejects are the pin working, not the splice. Same for payload sources:
    # negative tests harvest deliberately-broken text.
    def positive_inputs(exts=("input.k",)):
        out = []
        for dp, _d, fs in os.walk(REG):
            if args.cluster and args.cluster not in dp:
                continue
            if "MUST_ERROR" in fs:
                continue
            for ext in exts:
                if ext in fs:
                    out.append(os.path.join(dp, ext))
                    break
        return out

    inputs = positive_inputs()

    # coverage map is the WHOLE corpus — "uncovered" must be a property of
    # the suite, not of the sample we happen to evolve over
    all_inputs = positive_inputs(("input.k", "input.kz"))
    covered = set()
    cell_counts = defaultdict(int)
    for p in all_inputs:
        pairs, _own = scan_file(p)
        for pr in pairs:
            cell_counts[pr] += 1
        covered |= pairs
    rarity = dict(cell_counts)
    carriers = inputs[: args.max_tests]
    all_pairs = [(a, b) for a in CONSTRUCTS for b in REAL_CONTEXTS]
    uncovered = {c for c in all_pairs if c not in covered}
    print(f"corpus: {len(all_inputs)} inputs scanned for coverage, "
          f"{len(carriers)} carriers, {len(covered)} covered cells, "
          f"{len(uncovered)} uncovered targets")

    payloads = harvest_payloads(carriers)
    by_construct = defaultdict(list)
    for c, t in payloads:
        by_construct[c].append((c, t))
    print(f"payloads: {len(payloads)} subtrees across {len(by_construct)} constructs")

    # frontier bias: most splices aim at constructs/contexts that participate
    # in uncovered cells; the rest explore uniformly (don't collapse early)
    def line_opens(code: str) -> bool:
        s = code.rstrip()
        return (s.endswith("{") or s.endswith("|>")
                or code.lstrip()[0:1] in ("!", "|"))

    frontier_c = {a for (a, _b) in uncovered} & set(by_construct)
    frontier_x = {b for (_a, b) in uncovered}
    frontier_payloads = [p for p in payloads if p[0] in frontier_c]

    def carrier_contexts(path):
        ctxs = set()
        for ln in open(path, encoding="utf-8", errors="replace").read().splitlines():
            code = ln.split("//")[0]
            if code.strip() and line_opens(code):
                ctxs.update(k for k, rx in CONSTRUCTS.items() if rx.search(code))
        return ctxs

    frontier_carriers = [p for p in carriers if frontier_x & carrier_contexts(p)]
    if not frontier_carriers:
        frontier_carriers = carriers
    print(f"frontier: {len(frontier_c)} payload constructs, "
          f"{len(frontier_payloads)} payloads, {len(frontier_carriers)} carriers")

    def pick_payload():
        if frontier_payloads and rng.random() < 0.7:
            return rng.choice(frontier_payloads)
        return rng.choice(payloads)

    def pick_carrier():
        if rng.random() < 0.7:
            return rng.choice(frontier_carriers)
        return rng.choice(carriers)

    def rand_genome():
        n = rng.randint(1, args.splice_budget)
        return [Splice(pick_carrier(), rng.randint(0, 9999),
                       pick_payload()) for _ in range(n)]

    def mutate(g):
        g = list(g)
        op = rng.random()
        if op < 0.4 and g:                       # retarget payload
            i = rng.randrange(len(g))
            g[i] = Splice(g[i].carrier, g[i].hole, pick_payload())
        elif op < 0.7 and g:                     # retarget hole
            i = rng.randrange(len(g))
            g[i] = Splice(g[i].carrier, rng.randint(0, 9999), g[i].payload)
        elif op < 0.9 and len(g) < args.splice_budget:
            g.append(Splice(pick_carrier(), rng.randint(0, 9999),
                            pick_payload()))
        elif len(g) > 1:
            g.pop(rng.randrange(len(g)))
        return g

    def crossover(a, b):
        cut_a = rng.randint(0, len(a))
        cut_b = rng.randint(0, len(b))
        return a[:cut_a] + b[cut_b:]

    pop = [rand_genome() for _ in range(args.pop)]
    seen_srcs = set()
    evals = 0
    findings = []
    t0 = time.time()

    for gen in range(args.gens):
        scored = []
        for i, g in enumerate(pop):
            src, hits, all_hits, _s = eval_genome(g, uncovered)
            if src is None or src in seen_srcs:
                scored.append((-1.0, g, None, set(), False, "dup")); continue
            seen_srcs.add(src)
            ok, sig = koruc_check_text(src, f"g{gen}_{i}")
            f = fitness(hits, all_hits, ok, sig, rarity)
            scored.append((f, g, src, hits, ok, sig))
            evals += 1
        scored.sort(key=lambda x: -x[0])
        elite = [s for s in scored if s[0] > 0]
        for f, g, src, hits, ok, sig in elite[:5]:
            findings.append((gen, f, hits, ok, sig, src))
            print(f"gen{gen} fit={f:.0f} hits={sorted(hits)} "
                  f"verdict={'PASS' if ok else 'FAIL'} sig={sig[:80]}")

        # next generation: elites + tournament offspring
        pool = [s for s in scored if s[0] >= 0]
        if not pool:
            pop = [rand_genome() for _ in range(args.pop)]
            continue
        def tourn():
            return max(rng.sample(pool, min(4, len(pool))), key=lambda x: x[0])[1]
        nxt = [s[1] for s in scored[: max(2, args.pop // 8)]]  # elitism
        while len(nxt) < args.pop:
            if rng.random() < 0.3:
                nxt.append(mutate(crossover(tourn(), tourn())))
            else:
                nxt.append(mutate(tourn()))
        pop = nxt
        print(f"gen{gen}: best={scored[0][0]:.0f} pop_avg="
              f"{sum(s[0] for s in scored)/len(scored):.1f} evals={evals}")

    # write top findings
    fd = os.path.join(SCRATCH, "findings_gp")
    os.makedirs(fd, exist_ok=True)
    uniq = {}
    for gen, f, hits, ok, sig, src in findings:
        key = (tuple(sorted(hits)), ok)
        if key not in uniq or f > uniq[key][0]:
            uniq[key] = (f, gen, hits, ok, sig, src)
    for i, (key, (f, gen, hits, ok, sig, src)) in enumerate(sorted(
            uniq.items(), key=lambda kv: -kv[1][0])):
        d = os.path.join(fd, f"gp_{i}_{'pass' if ok else 'fail'}")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "input.k"), "w", newline="") as fo:
            fo.write(src)
        with open(os.path.join(d, "NOTE.txt"), "w") as fo:
            fo.write(f"gen={gen} fitness={f}\ncells={sorted(hits)}\n"
                     f"verdict={'PASS' if ok else 'FAIL'}\nsig={sig}\n")
    print(f"\ndone: evals={evals} unique_findings={len(uniq)} "
          f"({sum(1 for v in uniq.values() if v[3])} pass) in {time.time()-t0:.0f}s "
          f"→ {fd}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
