#!/usr/bin/env python3
"""check_deslop_census — the structural-clone census must not regrow
past its pinned baseline.

Runs tools/deslop.zig over the source root and compares the totals
against the baseline file. A regrowth fails with the delta and the top
offenders; the remedies are to fold the clones the census names into
their canonical form, or to re-pin the baseline in the same commit with
the reason the duplication is intentional. The census reads the working
tree — uncommitted work counts against the pin.

Usage: check_deslop_census.py <src_root> <deslop.zig> <baseline_file>
       [min_tokens]   (default 48; cwd is invariants/, so repo paths
       start with `..`)
"""

import re
import subprocess
import sys


def main():
    src_root, deslop_src, baseline_path = sys.argv[1:4]
    min_tokens = sys.argv[4] if len(sys.argv) > 4 else "48"

    baseline = {}
    try:
        with open(baseline_path) as f:
            for line in f:
                kv = re.match(r"^(\w+)=(\d+)\s*$", line)
                if kv:
                    baseline[kv.group(1)] = int(kv.group(2))
    except OSError:
        baseline = {}
    if "clusters" not in baseline or "members" not in baseline:
        print(f"BROKEN deslop-census: {baseline_path} needs "
              "clusters=<n> and members=<n> lines")
        return 2

    proc = subprocess.run(
        ["zig", "run", deslop_src, "--", src_root,
         "--top=8", f"--min-tokens={min_tokens}"],
        capture_output=True, text=True,
    )
    m = re.search(r"clusters: (\d+)\s+maximal members: (\d+)",
                  proc.stdout + proc.stderr)
    if proc.returncode != 0 or not m:
        print("BROKEN deslop-census: census did not run clean\n"
              + (proc.stdout + proc.stderr).strip()[-2000:])
        return 2

    clusters, members = int(m.group(1)), int(m.group(2))
    if clusters <= baseline["clusters"] and members <= baseline["members"]:
        print(f"deslop-census[{min_tokens}]: {clusters} clusters / "
              f"{members} members — at or under pin "
              f"({baseline['clusters']}/{baseline['members']})")
        return 0

    top = (proc.stdout + proc.stderr).split("\n\n", 1)[-1].strip()
    print(f"deslop-census[{min_tokens}] REGREW: {clusters} clusters / "
          f"{members} members "
          f"vs pin {baseline['clusters']}/{baseline['members']} "
          f"(+{clusters - baseline['clusters']}/"
          f"+{members - baseline['members']})\n\n{top}\n\n"
          "Fold the clones the census names, or re-pin "
          f"{baseline_path} in this commit with the reason the "
          "duplication is intentional.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
