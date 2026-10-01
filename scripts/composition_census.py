#!/usr/bin/env python3
"""Composition coverage census for challenge 007.

Maps which construct-under-context cells the regression corpus already
covers, so a composition fuzzer (or a human contestant) can aim at uncovered
cells instead of re-covering known ones.

Constructs and spellings are corpus-derived (007's rule: never invent):
each detector is a regex proven by grepping real tests. "A under B" means
construct A appears on a line indented deeper than the line where construct
B's block opened — indentation is the tree.

Usage:
  python3 scripts/composition_census.py [--json] [--uncovered] [--cluster S]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REG = os.path.join(ROOT, "tests", "regression")

# construct name -> regex on the *code* part of a line (comments stripped).
# Grounded: each pattern was verified against corpus hits.
CONSTRUCTS = {
    "capture":      re.compile(r"\bcaptured?\s*\{"),
    "for_each":     re.compile(r"\bfor\(|!\s*each\b"),
    "if_cond":      re.compile(r"\bif\("),
    "effect_arm":   re.compile(r"^\s*!\s+\S"),
    "branch_arm":   re.compile(r"^\s*\|\s+\S"),
    "pipeline":     re.compile(r"\|>"),
    "bare_return":  re.compile(r"(?<![|!:=])\s->\s"),
    "bind":         re.compile(r":\s*[a-zA-Z_]\w*\s*(?:\|>|->|$)"),
    "subflow_impl": re.compile(r"^\s*[a-zA-Z_][\w-]*\s*="),
    "store":        re.compile(r"std/store:"),
    "phantom":      re.compile(r"<[a-zA-Z][\w-]*>"),
    "obligation":   re.compile(r"<[a-zA-Z][\w-]*!>|<![a-zA-Z][\w-]*>"),
    "glob":         re.compile(r":\*|->\s*\*\s*$"),
    "record":       re.compile(r"\{[^}]*:[^}]*\}"),
    "read_lines":   re.compile(r"read[-_.]?lines", re.I),
    "string_br":    re.compile(r'^\s*\|\s*"'),
    "proc_zig":     re.compile(r"\|zig\b"),
    "when":         re.compile(r"\bwhen\("),
}

COMMENT = re.compile(r"//")


def code_part(line: str) -> str:
    p = line.find("//")
    return line if p < 0 else line[:p]


def scan_file(path: str):
    """Return set of (construct, context) pairs: construct appears indented
    inside the block opened by a context-construct line."""
    pairs = set()
    own = set()
    stack = []  # (indent, construct) — open blocks
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        return pairs, own
    for line in lines:
        code = code_part(line)
        if not code.strip() or code.strip().startswith("//"):
            continue
        indent = len(line) - len(line.lstrip())
        hits = [k for k, rx in CONSTRUCTS.items() if rx.search(code)]
        while stack and indent <= stack[-1][0]:
            stack.pop()
        for h in hits:
            own.add(h)
            for _, ctx in stack:
                pairs.add((h, ctx))
        # a line that opens a block (ends with { or is an arm/step head)
        # pushes its constructs as context for deeper lines
        if hits and (code.rstrip().endswith("{") or code.lstrip()[0:1] in ("!", "|")
                     or re.search(r"\|>\s*$", code)):
            stack.append((indent, hits[0] if len(hits) == 1 else tuple(sorted(hits))))
            # multi-hit lines register each hit as context
            if len(hits) > 1:
                stack.pop()
                for h in hits:
                    stack.append((indent, h))
    return pairs, own


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--uncovered", action="store_true",
                    help="print construct pairs never co-nested in the corpus")
    ap.add_argument("--cluster", default=None)
    args = ap.parse_args()

    coverage = defaultdict(set)   # (construct, context) -> set of test dirs
    presence = defaultdict(set)   # construct -> test dirs
    for dirpath, _dirs, files in os.walk(REG):
        if "input.k" not in files and "input.kz" not in files:
            continue
        base = os.path.basename(dirpath)
        if args.cluster and args.cluster not in dirpath:
            continue
        for fn in ("input.k", "input.kz"):
            p = os.path.join(dirpath, fn)
            if not os.path.exists(p):
                continue
            pairs, own = scan_file(p)
            for c in own:
                presence[c].add(base)
            for pr in pairs:
                coverage[pr].add(base)
            break  # one input file per test

    constructs = sorted(presence)
    if args.json:
        print(json.dumps({
            "constructs": constructs,
            "counts": {c: len(presence[c]) for c in constructs},
            "coverage": {f"{a} under {b}": sorted(v) for (a, b), v in sorted(coverage.items())},
        }, indent=1))
        return 0

    print(f"corpus: {sum(len(v) for v in presence.values())} construct hits, "
          f"{len(coverage)} distinct nested pairs")
    print("\nconstruct presence (tests each):")
    for c in constructs:
        print(f"  {c:14s} {len(presence[c]):4d}")

    if args.uncovered:
        # contexts must lexically open an indented body: `{` blocks, arm
        # heads, chain continuations. signature-level constructs (phantom,
        # obligation, bind, bare_return, subflow_impl, glob, read_lines,
        # proc_zig, string_br) are payloads, not containers — a `-> { .. }`
        # record tail is not a body.
        real_contexts = {b for (_a, b) in coverage} & {
            "capture", "for_each", "if_cond", "effect_arm", "branch_arm",
            "pipeline", "record", "store", "glob"}
        print("\nuncovered cells (real contexts only — something nests under each):")
        seen_pairs = set(coverage)
        n = 0
        for a in constructs:
            for b in constructs:
                if a == b or (a, b) in seen_pairs or b not in real_contexts:
                    continue
                if presence[a] and presence[b]:
                    n += 1
                    print(f"  {a:14s} under {b}")
        print(f"\n{n} uncovered ordered pairs across {len(real_contexts)} real contexts")
    else:
        print("\ncoverage matrix (nested counts):")
        hdr = " " * 15 + " ".join(f"{b[:5]:>6s}" for b in constructs)
        print(hdr)
        for a in constructs:
            row = f"{a:15s}"
            for b in constructs:
                n = len(coverage.get((a, b), ()))
                row += f"{n:6d}"
            print(row)
    return 0


if __name__ == "__main__":
    sys.exit(main())
