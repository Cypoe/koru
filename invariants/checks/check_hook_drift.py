#!/usr/bin/env python3
"""installed-hooks-match-source — the tracked hooks/ files are canonical; the
copies under .git/hooks are what actually enforce. A diff means an edit landed
without reaching the enforcement that reads it: the commit record says the new
rule while the hook enforces the old one. Fix: bash hooks/install.sh.

Only reachable when pre-commit itself is installed (this check runs inside the
gate it audits) — a missing pre-commit is invisible by construction, which is
why every other drift is flagged loudly instead.
"""
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GITDIR = subprocess.run(
    ["git", "-C", ROOT, "rev-parse", "--git-common-dir"],
    capture_output=True, text=True,
).stdout.strip()
if not GITDIR:
    print("BROKEN: git rev-parse --git-common-dir returned nothing", file=sys.stderr)
    sys.exit(2)
if not os.path.isabs(GITDIR):
    GITDIR = os.path.join(ROOT, GITDIR)

drift = 0
for name in sorted(os.listdir(os.path.join(ROOT, "hooks"))):
    if name == "install.sh":
        continue  # the installer, not a hook
    src = os.path.join(ROOT, "hooks", name)
    if not os.path.isfile(src):
        continue
    dst = os.path.join(GITDIR, "hooks", name)
    if not os.path.isfile(dst):
        print(f"DRIFT  {name}: not installed — run bash hooks/install.sh")
        drift = 1
    elif not os.access(dst, os.X_OK):
        print(f"DRIFT  {name}: installed copy lost its exec bit — run bash hooks/install.sh")
        drift = 1
    elif open(src, "rb").read() != open(dst, "rb").read():
        print(f"DRIFT  {name}: hooks/ ≠ .git/hooks — tracked is canonical; run bash hooks/install.sh")
        drift = 1

if not drift:
    print("installed hooks match hooks/ sources")
sys.exit(drift)
