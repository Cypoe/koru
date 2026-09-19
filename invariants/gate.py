#!/usr/bin/env python3
"""gate — the git-gate consumer of `koruc invariants` output.

For each git-gate-tagged invariant row:
  - `check:` declared  → run it (deterministic; non-zero blocks the commit)
  - no `check:`        → judge the staged diff via the compiled gate binary
                         (koru/odds; advisory unless GATE_BLOCK=1)

A row's execution strategy is read off the declaration itself — `check:`
means a deterministic checker exists; its absence means the rule is
judgment-class and goes to the reader (Jev). That is the designed split:
the decidable get scripts, the readable get a model.

Usage:
  python3 gate.py [--checks-only] [--judge-only]

Environment:
  GATE_BLOCK=1        Jev VIOLATION verdicts also fail the gate
  OPENROUTER_API_KEY  required for live judgments; absent, judge rows
                      report UNJUDGED loudly — never a silent pass

The gate binary (a.out, from gate.k) is built on first run and whenever
gate.k is newer than it — the stale-binary discipline applied to the gate
itself.
"""

import os
import re
import shlex
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
KORUC = os.path.join(HERE, "..", "zig-out", "bin", "koruc")
GATE_BIN = os.path.join(HERE, "a.out")
GATE_SRC = os.path.join(HERE, "gate.k")


def koruc_invariants():
    """Run `koruc invariants.kz invariants`; return combined output.

    The listing prints via std.debug.print — stderr — interleaved with
    build noise on first compile. The parser is tolerant of both.
    """
    proc = subprocess.run(
        [KORUC, "invariants.kz", "invariants"],
        cwd=HERE, capture_output=True, text=True,
    )
    return proc.stdout + proc.stderr


def parse_listing(text):
    """Rows of the listing: name, tags, loc, rule, check — tolerant of
    compiler noise lines that match none of the row shapes."""
    rows = []
    cur = None
    kind = None
    for line in text.splitlines():
        if line in ("inferred", "aspirational"):
            kind = line
            continue
        m = re.match(r"^  (\S+)\s*(\[.*\])?\s*$", line)
        if m and not line.startswith("    "):
            cur = {"name": m.group(1), "tags": m.group(2) or "",
                   "kind": kind, "loc": "", "rule": "", "check": ""}
            rows.append(cur)
            continue
        if cur is None:
            continue
        if line.startswith("    check: "):
            cur["check"] = line[len("    check: "):]
        elif line.startswith("    "):
            body = line.strip()
            if re.match(r"^[^:]+:\d+$", body):
                cur["loc"] = body
            elif body:
                cur["rule"] = body
    return rows


def git_staged_diff():
    proc = subprocess.run(
        ["git", "diff", "--staged"], cwd=HERE, capture_output=True, text=True,
    )
    return proc.stdout


def ensure_gate_binary():
    if os.path.exists(GATE_BIN) and os.path.getmtime(GATE_BIN) >= os.path.getmtime(GATE_SRC):
        return True
    proc = subprocess.run(
        [KORUC, "build", "gate.k"], cwd=HERE, capture_output=True, text=True,
    )
    if proc.returncode != 0 or not os.path.exists(GATE_BIN):
        sys.stderr.write(proc.stdout + proc.stderr)
        print("gate: FAILED to build gate.k — the judge path has no binary", file=sys.stderr)
        return False
    return True


def judge(question, state):
    proc = subprocess.run(
        [GATE_BIN, question, state], cwd=HERE, capture_output=True, text=True,
    )
    line = (proc.stdout.strip().splitlines() or ["UNJUDGED no output"])[0]
    return line


def main():
    args = sys.argv[1:]
    known = {"--checks-only", "--judge-only"}
    unknown = [a for a in args if a not in known]
    if unknown:
        print(f"gate: unknown flag(s) {' '.join(unknown)} — there is no "
              "offline mode; judgment rows need OPENROUTER_API_KEY",
              file=sys.stderr)
        return 1
    checks_only = "--checks-only" in args
    judge_only = "--judge-only" in args
    block = os.environ.get("GATE_BLOCK") == "1"

    if not os.path.exists(KORUC):
        print("gate: no koruc binary at zig-out/bin/koruc — build the "
              "compiler first (zig build)", file=sys.stderr)
        return 1

    rows = [r for r in parse_listing(koruc_invariants())
            if '"git-gate"' in r["tags"]]

    if not rows:
        print("gate: no git-gate-tagged invariants declared")
        return 0

    diff = git_staged_diff()
    have_diff = bool(diff.strip())
    want_judge = any(not r["check"] for r in rows)
    if want_judge and not checks_only and have_diff:
        if not ensure_gate_binary():
            return 1

    failures = []
    advisories = []

    for r in rows:
        if r["check"]:
            if judge_only:
                continue
            proc = subprocess.run(
                shlex.split(r["check"]), cwd=HERE, capture_output=True, text=True,
            )
            if proc.returncode != 0:
                tail = "\n".join((proc.stdout + proc.stderr).strip().splitlines()[-8:])
                failures.append(f"check FAIL  {r['name']}\n{tail}")
            else:
                print(f"check ok    {r['name']}")
        else:
            if checks_only:
                continue
            if not have_diff:
                print(f"judge skip  {r['name']} — no staged changes")
                continue
            verdict = judge(r["rule"], diff)
            if verdict.startswith("VIOLATION"):
                if block:
                    failures.append(f"judge VIOLATION {r['name']}  {verdict}")
                else:
                    advisories.append(f"judge flags   {r['name']}  {verdict}  (advisory; GATE_BLOCK=1 to enforce)")
            elif verdict.startswith("CLEAN"):
                print(f"judge ok    {r['name']}  {verdict}")
            elif block:
                failures.append(f"judge UNJUDGED {r['name']}  {verdict} — "
                                "enforcement is on and the row could not be judged")
            else:
                advisories.append(f"judge UNJUDGED {r['name']}  {verdict}")

    for a in advisories:
        print(a)
    for f in failures:
        print(f, file=sys.stderr)

    if failures:
        print(f"\ngate: {len(failures)} blocking violation(s)", file=sys.stderr)
        return 1
    mode = "enforcing" if block else "advisory"
    print(f"gate: {len(rows)} row(s), {mode} — clean" if not advisories
          else f"gate: {len(rows)} row(s), {mode} — {len(advisories)} flag(s) above")
    return 0


if __name__ == "__main__":
    sys.exit(main())
