#!/usr/bin/env python3
"""gate — the git-gate consumer of `koruc invariants` output.

For each git-gate-tagged invariant row:
  - `check:` declared  → run it (deterministic; non-zero blocks the commit)
  - no `check:`        → judge the staged diff via the compiled gate binary
                         (koru/odds; advisory unless GATE_BLOCK=1)

A `git-gate-local` row is colocated: it is declared inside the file it
guards and fires ONLY when that file is in a staged diff — judged
against that file's hunks alone, in whichever repository owns the file
(the manifest imports koru/odds so that package's own declaration is
listed and fires on koru-libs commits). A local row whose file is not
staged did not fire — that is a skip, never an UNJUDGED.

A row's execution strategy is read off the declaration itself — `check:`
means a deterministic checker exists; its absence means the rule is
judgment-class and goes to the reader (Jev). That is the designed split:
the decidable get scripts, the readable get a model.

An `odds-N` tag samples the row: it fires only when a deterministic roll
of sha256(row name + staged diff) mod 100 lands below N — an alarm driven
by commit activity, not a schedule. The roll is fixed for a given staged
state, so re-running the gate on the same diff answers identically; it is
unpredictable only until the diff exists. Sampling a judged row makes a
flaky oracle — the tag's home is `check:` rows, where a firing alarm
always has a concrete script output to point at.

A `repo-<name>` tag points a check at a consumer repo: the row's `check:`
runs only when `--repo` gates that repo (matched on the repo directory's
basename), and skips otherwise — the mirror of `manifest_repo` scoping.
Checks still execute from this directory; the check command carries the
foreign paths it instruments.

Usage:
  python3 gate.py [--checks-only] [--judge-only] [--repo PATH]

`--repo` names the repository whose staged diff is gated (default: the
manifest's own repo — the one containing this file). Other Koru
consumers wire this script into their pre-commit with `--repo $ROOT`:
judgment rows are universal and fire on that repo's diff, `check:` rows
are instruments of THIS repo's tree and skip elsewhere, and
git-gate-local rows resolve their own file's repo regardless.

Environment:
  GATE_BLOCK=1        Jev VIOLATION and UNJUDGED verdicts fail the gate
  OPENROUTER_API_KEY  required for live judgments; when unset, the gate
                      sources ~/.config/koru/openrouter.env (a KEY=VALUE
                      file outside every repo). Still absent → judge rows
                      report UNJUDGED loudly — never a silent pass

The gate binary (a.out, from gate.k) is built on first run and whenever
gate.k or a linked module (koru/odds) is newer than it — the stale-binary
discipline applied to the gate itself.
"""

import hashlib
import os
import re
import shlex
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST_REPO = os.path.dirname(HERE)
KORUC = os.path.join(HERE, "..", "zig-out", "bin", "koruc")
GATE_BIN = os.path.join(HERE, "a.out")
GATE_SRC = os.path.join(HERE, "gate.k")

# The judge's input window, measured 2026-09-21 against
# typesafe/jev-1.13-20260917 via OpenRouter: a 100KB state judged fine,
# 147KB refused with HTTP 400 max_tokens_exceeded. The real bound is
# tokens — bytes is the proxy the gate can see — so this sits
# deliberately under the measured cliff. A state past it is not a
# judgment failure; it is an input the judge cannot hold, and the
# honest answer is UNJUDGED with the cause named.
JUDGE_STATE_MAX_BYTES = 96_000


def koruc_invariants():
    """Run `koruc invariants.kz invariants`; return (rc, combined output).

    The listing prints via std.debug.print — stderr — interleaved with
    build noise on first compile. The parser is tolerant of both.
    """
    proc = subprocess.run(
        [KORUC, "invariants.kz", "invariants"],
        cwd=HERE, capture_output=True, text=True,
    )
    return proc.returncode, proc.stdout + proc.stderr


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


def git_staged_diff(repo):
    proc = subprocess.run(
        ["git", "-C", repo, "diff", "--staged"],
        capture_output=True, text=True,
    )
    return proc.stdout


def loc_file(loc):
    """A row's loc (`file:line`) → absolute path. The listing prints
    paths relative to its cwd (this directory) for in-repo files,
    absolute for out-of-repo ones."""
    f = loc.rsplit(":", 1)[0] if loc else ""
    if f and not os.path.isabs(f):
        f = os.path.join(HERE, f)
    return os.path.normpath(f) if f else ""


def file_staged_diff(path):
    """The staged diff touching one file, in whatever repository owns
    it. None when the file is not staged anywhere — the local row's
    `did not fire` answer."""
    d = path
    while not os.path.isdir(d):
        nd = os.path.dirname(d)
        if nd == d:
            return None
        d = nd
    proc = subprocess.run(
        ["git", "-C", d, "rev-parse", "--show-toplevel"],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        return None
    rel = os.path.relpath(path, proc.stdout.strip())
    proc = subprocess.run(
        ["git", "-C", proc.stdout.strip(), "diff", "--staged", "--", rel],
        capture_output=True, text=True,
    )
    return proc.stdout if proc.stdout.strip() else None


# The gate binary's freshness oracle: gate.k plus the modules it links.
# koru/odds is the only live dep today — its path resolves through
# koru.json's "koru" mapping to ../../koru-libs.
GATE_DEPS = [
    GATE_SRC,
    os.path.join(HERE, "..", "..", "koru-libs", "odds", "index.kz"),
]


def ensure_gate_binary():
    newest = max(os.path.getmtime(f) for f in GATE_DEPS if os.path.exists(f))
    if os.path.exists(GATE_BIN) and os.path.getmtime(GATE_BIN) >= newest:
        return True
    proc = subprocess.run(
        [KORUC, "build", "gate.k"], cwd=HERE, capture_output=True, text=True,
    )
    if proc.returncode != 0 or not os.path.exists(GATE_BIN):
        sys.stderr.write(proc.stdout + proc.stderr)
        print("gate: FAILED to build gate.k — the judge path has no binary", file=sys.stderr)
        return False
    return True


def provision_key():
    """OPENROUTER_API_KEY from env, else ~/.config/koru/openrouter.env —
    the one canonical credential location, outside every repo."""
    if os.environ.get("OPENROUTER_API_KEY"):
        return
    try:
        with open(os.path.expanduser("~/.config/koru/openrouter.env")) as f:
            for line in f:
                if line.startswith("OPENROUTER_API_KEY="):
                    os.environ["OPENROUTER_API_KEY"] = \
                        line.split("=", 1)[1].strip().strip('"').strip("'")
                    return
    except OSError:
        pass


def judge(question, state):
    proc = subprocess.run(
        [GATE_BIN, question, state], cwd=HERE, capture_output=True, text=True,
    )
    line = (proc.stdout.strip().splitlines() or ["UNJUDGED no output"])[0]
    return line


def main():
    args = sys.argv[1:]
    repo = MANIFEST_REPO
    rest = []
    i = 0
    while i < len(args):
        if args[i] == "--repo":
            i += 1
            if i >= len(args):
                print("gate: --repo takes a path", file=sys.stderr)
                return 1
            repo = os.path.abspath(args[i])
        else:
            rest.append(args[i])
        i += 1
    args = rest
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
    manifest_repo = os.path.realpath(repo) == os.path.realpath(MANIFEST_REPO)

    if not os.path.exists(KORUC):
        print("gate: no koruc binary at zig-out/bin/koruc — build the "
              "compiler first (zig build)", file=sys.stderr)
        return 1

    rc, listing = koruc_invariants()
    all_rows = parse_listing(listing)
    if rc != 0 or not all_rows:
        # A manifest that can't be read is not an empty manifest — the
        # gate must not pass on silence (compiler red, koruc crash).
        tail = "\n".join(listing.strip().splitlines()[-6:])
        print(f"gate: BROKEN — `koruc invariants.kz invariants` produced no "
              f"listing (exit {rc}); a gate that cannot read its manifest "
              f"judges nothing\n{tail}", file=sys.stderr)
        return 1
    rows = [r for r in all_rows
            if '"git-gate"' in r["tags"] or '"git-gate-local"' in r["tags"]]

    if not rows:
        print("gate: no git-gate-tagged invariants declared")
        return 0

    provision_key()
    diff = git_staged_diff(repo)
    have_diff = bool(diff.strip())
    binary_ready = False

    failures = []
    advisories = []

    for r in rows:
        m = re.search(r'odds-(\d+)', r["tags"])
        if m:
            n = int(m.group(1))
            roll = int.from_bytes(hashlib.sha256(
                r["name"].encode() + b"\0" + diff.encode()).digest()[:8],
                "big") % 100
            if roll >= n:
                print(f"odds miss  {r['name']} — rolled {roll}, fires below {n}")
                continue
            print(f"odds fire  {r['name']} — rolled {roll} < {n}")
        local = '"git-gate-local"' in r["tags"]
        state = diff
        if local:
            path = loc_file(r["loc"])
            if not path:
                failures.append(f"local FAIL  {r['name']} — declaration "
                                "carries no file location to scope to")
                continue
            fdiff = file_staged_diff(path)
            if fdiff is None:
                print(f"local skip  {r['name']} — "
                      f"{r['loc'].rsplit(':', 1)[0] or '???'} not in a staged diff")
                continue
            state = fdiff
        if r["check"]:
            if judge_only:
                continue
            repo_m = re.search(r'repo-([a-z0-9_-]+)', r["tags"])
            if repo_m:
                if repo_m.group(1) != os.path.basename(
                        os.path.realpath(repo)):
                    print(f"check skip  {r['name']} — instruments "
                          f"{repo_m.group(1)}")
                    continue
            elif not manifest_repo:
                print(f"check skip  {r['name']} — repo-scoped to "
                      f"{os.path.basename(MANIFEST_REPO)}")
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
            if not local and not have_diff:
                print(f"judge skip  {r['name']} — no staged changes")
                continue
            if not binary_ready:
                binary_ready = True
                if not ensure_gate_binary():
                    return 1
            if len(state.encode()) > JUDGE_STATE_MAX_BYTES:
                verdict = (f"UNJUDGED state {len(state.encode())}B exceeds the "
                           f"judge's context (~{JUDGE_STATE_MAX_BYTES}B measured "
                           "— split the commit or scope the row narrower)")
            else:
                verdict = judge(r["rule"], state)
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
