#!/usr/bin/env python3
"""Seed material for the native koru GA driver (.kfuzz/ga/ga.k).

The koru GA owns selection/evaluation/breeding; this script is offline data
prep only — it emits the fragment bank, seed population, and target cells
the in-language search consumes. Everything derives from the corpus via the
same detectors the census and GP use; nothing invents syntax.

Outputs:
  .kfuzz/ga/bank/<ctor>__<i>.frag   subtree payloads, dedented to col 0
  .kfuzz/ga/pop/g0/*.k             seed carriers (positive corpus inputs)
  .kfuzz/ga/targets.txt            uncovered cells, one "ctx__ctor" per line

Usage: python3 scripts/ga_prep.py [--seeds N] [--per-ctor N]
"""

from __future__ import annotations

import argparse
import os
import random
import shutil
import subprocess
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REG = os.path.join(ROOT, "tests", "regression")
GA = os.path.join(ROOT, ".kfuzz", "ga")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from composition_census import scan_file, CONSTRUCTS
from composition_gp import harvest_payloads, REAL_CONTEXTS


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip())


def positive_inputs(exts=("input.k",)):
    out = []
    for dp, _d, fs in os.walk(REG):
        if "MUST_ERROR" in fs:
            continue
        for ext in exts:
            if ext in fs:
                out.append(os.path.join(dp, ext))
                break
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", type=int, default=14)
    ap.add_argument("--per-ctor", type=int, default=4)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()
    rng = random.Random(args.seed)

    # coverage over the whole positive corpus — the same map the GP uses
    all_inputs = positive_inputs(("input.k", "input.kz"))
    covered = set()
    for p in all_inputs:
        pairs, _own = scan_file(p)
        covered |= pairs
    uncovered = {(a, b) for a in CONSTRUCTS for b in REAL_CONTEXTS
                 if (a, b) not in covered}

    # carriers: prefer seeds whose openers touch frontier contexts
    carriers = positive_inputs()
    frontier_x = {b for (_a, b) in uncovered}
    def ctxs_of(path):
        out = set()
        for ln in open(path, encoding="utf-8", errors="replace").read().splitlines():
            code = ln.split("//")[0]
            if code.strip():
                out.update(k for k, rx in CONSTRUCTS.items() if rx.search(code))
        return out
    rng.shuffle(carriers)
    front = [c for c in carriers if ctxs_of(c) & frontier_x]

    # seeds must check clean STANDALONE at their pop location — corpus
    # tests importing sibling modules (app/ops et al.) pass at their own
    # dir but refuse after relocation, so verify the COPY not the source
    koruc = os.environ.get("KORUC", os.path.join(ROOT, "zig-out", "bin", "koruc"))
    pop0 = os.path.join(GA, "pop", "g0")
    os.makedirs(pop0, exist_ok=True)
    def compiles_at_pop(src):
        probe = os.path.join(pop0, "_probe.k")
        shutil.copy(src, probe)
        try:
            return subprocess.run([koruc, "-c", probe], cwd=ROOT,
                                  capture_output=True, timeout=60).returncode == 0
        except subprocess.TimeoutExpired:
            return False
        finally:
            os.unlink(probe)
    seeds = []
    for c in front + carriers:
        if len(seeds) >= args.seeds:
            break
        if compiles_at_pop(c):
            seeds.append(c)

    payloads = harvest_payloads(seeds + carriers[:300])
    by_ctor = defaultdict(list)
    for c, t in payloads:
        by_ctor[c].append(t)

    os.makedirs(os.path.join(GA, "bank"), exist_ok=True)
    os.makedirs(os.path.join(GA, "findings"), exist_ok=True)

    n_frag = 0
    for ctor, texts in sorted(by_ctor.items()):
        for i, t in enumerate(texts[: args.per_ctor]):
            lines = t.splitlines()
            base = indent_of(lines[0])
            body = "\n".join(l[base:] if l.strip() else "" for l in lines)
            with open(os.path.join(GA, "bank", f"{ctor}__{i}.frag"), "w",
                      encoding="utf-8", newline="") as f:
                f.write(body + "\n")
            n_frag += 1

    for i, s in enumerate(seeds):
        shutil.copy(s, os.path.join(GA, "pop", "g0", f"s{i:03d}.k"))

    with open(os.path.join(GA, "targets.txt"), "w", encoding="utf-8", newline="") as f:
        for a, b in sorted(uncovered):
            f.write(f"{b}__{a}\n")  # ctx__ctor — breed labels cells this way

    print(f"ga_prep: {len(seeds)} seeds ({len(front)} frontier), "
          f"{n_frag} frags across {len(by_ctor)} constructs, "
          f"{len(uncovered)} targets → {os.path.relpath(GA, ROOT)}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
