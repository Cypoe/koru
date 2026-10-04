#!/usr/bin/env python3
"""kz_sweep_manifest — the facet sweep's candidate list, regenerated.

Walks every tracked .kz in the repo, asks the parser
(`koruc --check-k-convertible`) whether the file carries host content, and
assigns each a lane for the facet-sweep challenge:

  convert-test     CONVERTIBLE input/fixture in a positive test dir —
                   convert, run the test, green is the done-gate
  convert-other    CONVERTIBLE .kz outside tests/ — convert, then compile a
                   consumer (`koruc -c`) as the done-gate
  error-pin-review CONVERTIBLE inside an error-marked dir — judgment: is the
                   .kz facet part of the pin (e.g. a bare-line-as-host_line
                   test), or incidental? Convert only if the same refusal
                   still fires as .k; otherwise leave it and record why
  near-pure        NOT_CONVERTIBLE with <=3 host items and no proc_decl —
                   the gradient: a stray host line is residue (drop it, the
                   file becomes convertible) or load-bearing (stays .kz —
                   a comment saying why helps the next reader)
  exempt           exempted by the gate's own grammar (expected.json /
                   LANGUAGES / MUST_ERROR / input.k sibling / tests/broken /
                   allow file) — listed so "skipped" is a decision, not drift
  earned           NOT_CONVERTIBLE with >3 host items or a proc — honest .kz
  unparseable      the flag could not parse it — error pins and `part` files;
                   out of scope, counted so nothing hides

Usage:
  kz_sweep_manifest.py                 # full manifest TSV to stdout
  kz_sweep_manifest.py --summary       # lane counts only
  kz_sweep_manifest.py --lane convert-test   # one lane only
  kz_sweep_manifest.py --slice 2 --of 4      # deterministic slice for a contestant
"""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
KORUC = os.path.join(REPO, "zig-out", "bin", "koruc")

sys.path.insert(0, os.path.join(REPO, "invariants", "checks"))
from check_kz_preference import exempted  # noqa: E402 — one exemption grammar

ALLOW_PATH = os.path.join(REPO, "invariants", "checks", "kz-preference.allow")
ALLOW = {}
if os.path.exists(ALLOW_PATH):
    for _ln in open(ALLOW_PATH):
        _ln = _ln.strip()
        if not _ln or _ln.startswith("#"):
            continue
        _path, _, _reason = (p.strip() for p in _ln.partition("|"))
        if _reason:
            ALLOW[_path] = _reason


def classify(path):
    proc = subprocess.run([KORUC, path, "--check-k-convertible"],
                          capture_output=True, text=True, cwd=REPO)
    parts = proc.stdout.strip().split("\t")
    status = parts[0]
    host = {"host_line": 0, "host_type_decl": 0, "proc_decl": 0}
    if len(parts) > 2:
        for kv in parts[2].split():
            k, _, v = kv.partition("=")
            if k in host:
                host[k] = int(v)
    if status == "UNPARSEABLE":
        return (path, "unparseable", host, "")
    if status == "CONVERTIBLE":
        reason = exempted(REPO, path, ALLOW)
        if reason:
            if "EXPECT" in reason or "MUST_ERROR" in reason:
                return (path, "error-pin-review", host, reason)
            return (path, "exempt", host, reason)
        d = os.path.dirname(os.path.join(REPO, path))
        if os.path.basename(path) == "input.kz" and os.path.exists(os.path.join(d, "SUCCESS")):
            return (path, "convert-test", host, "")
        return (path, "convert-other", host, "")
    # NOT_CONVERTIBLE
    n = sum(host.values())
    if n <= 3 and host["proc_decl"] == 0:
        return (path, "near-pure", host, f"host_line={host['host_line']} host_type_decl={host['host_type_decl']}")
    return (path, "earned", host, "")


def main():
    args = sys.argv[1:]
    if "--summary" in args:
        args.remove("--summary")
        summary_only = True
    else:
        summary_only = False
    lane_filter = None
    slice_i = slice_n = None
    i = 0
    while i < len(args):
        if args[i] == "--lane":
            i += 1
            lane_filter = args[i]
        elif args[i] == "--slice":
            i += 1
            slice_i = int(args[i])
        elif args[i] == "--of":
            i += 1
            slice_n = int(args[i])
        i += 1

    proc = subprocess.run(["git", "-C", REPO, "ls-files", "*.kz"],
                          capture_output=True, text=True)
    paths = [p for p in proc.stdout.splitlines() if p]

    with ThreadPoolExecutor(max_workers=8) as pool:
        rows = list(pool.map(classify, paths))
    rows.sort(key=lambda r: r[0])

    if slice_i is not None and slice_n:
        rows = [r for idx, r in enumerate(rows) if idx % slice_n == slice_i - 1]
    if lane_filter:
        rows = [r for r in rows if r[1] == lane_filter]

    if summary_only:
        counts = {}
        for _, lane, _, _ in rows:
            counts[lane] = counts.get(lane, 0) + 1
        for lane in sorted(counts):
            print(f"{counts[lane]:5d}  {lane}")
        return 0

    for path, lane, host, note in rows:
        print(f"{lane}\t{path}\t{host['host_line']}/{host['host_type_decl']}/{host['proc_decl']}\t{note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
