#!/usr/bin/env python3
"""installed-hooks-match-source — the tracked hooks/ files are canonical; the
copies under .git/hooks are what actually enforce. A diff means an edit landed
without reaching the enforcement that reads it: the commit record says the new
rule while the hook enforces the old one. Fix: bash hooks/install.sh.

Usage:
  check_hook_drift.py                    # audit THIS repo (all hooks, incl. shims)
  check_hook_drift.py REPO --payloads-only
      # audit a consumer repo's .git/hooks against this repo's hooks/ — the
      # .cjs payloads only. Shell shims legitimately vary downstream (a
      # consumer's pre-commit calls gate.py --repo; a repo may run its own
      # dispatcher). The payloads carry the shared law; those must match.

Only reachable when pre-commit itself is installed (this check runs inside the
gate it audits) — a missing pre-commit is invisible by construction, which is
why every other drift is flagged loudly instead.
"""
import os
import subprocess
import sys

def die(msg):
    print(f"BROKEN: {msg}", file=sys.stderr)
    sys.exit(2)

HERE = os.path.dirname(os.path.abspath(__file__))
KORU_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CANON = os.path.join(KORU_ROOT, "hooks")

payloads_only = "--payloads-only" in sys.argv
args = [a for a in sys.argv[1:] if not a.startswith("--")]
TARGET = os.path.abspath(args[0]) if args else KORU_ROOT

gd = subprocess.run(
    ["git", "-C", TARGET, "rev-parse", "--git-common-dir"],
    capture_output=True, text=True,
).stdout.strip()
if not gd:
    die(f"git rev-parse --git-common-dir returned nothing for {TARGET}")
if not os.path.isabs(gd):
    gd = os.path.join(TARGET, gd)
HOOKDIR = os.path.join(gd, "hooks")

drift = 0
for name in sorted(os.listdir(CANON)):
    if name == "install.sh":
        continue  # the installer, not a hook
    if payloads_only and not name.endswith(".cjs"):
        continue  # consumer shims legitimately vary; payloads carry the law
    src = os.path.join(CANON, name)
    if not os.path.isfile(src):
        continue
    dst = os.path.join(HOOKDIR, name)
    if not os.path.isfile(dst):
        print(f"DRIFT  {name}: not installed in {TARGET} — run bash hooks/install.sh {TARGET}")
        drift = 1
    elif open(src, "rb").read() != open(dst, "rb").read():
        print(f"DRIFT  {name}: hooks/ ≠ {TARGET}'s installed copy — koru/hooks is canonical; run bash hooks/install.sh {TARGET}")
        drift = 1
    elif not payloads_only and not os.access(dst, os.X_OK):
        print(f"DRIFT  {name}: installed copy lost its exec bit — run bash hooks/install.sh")
        drift = 1

if not drift:
    scope = "payloads " if payloads_only else ""
    print(f"installed {scope}hooks match hooks/ sources in {TARGET}")
sys.exit(drift)
