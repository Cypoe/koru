#!/usr/bin/env python3
"""Split koru_std/store.kz into `~part` files, one per event.

Mechanical, verifiable move: every event's region (its doc banner + decl +
implementation) moves verbatim into store.<event>.kz; the primary keeps the
header + shared host infrastructure + `~part` declarations. The regions
partition the original file contiguously, so the split is byte-faithful —
the merged module is item-for-item the file as it stood.

Run: python3 scripts/split_store.py
"""
import re
from pathlib import Path

SRC = Path("koru_std/store.kz")
EVENTS = [
    (1691, "new"), (8206, "view"), (8280, "stored"), (9153, "default"),
    (9224, "watch"), (9519, "insert"), (9996, "rule"), (10137, "query"),
    (11549, "preorder"), (11652, "take"), (11822, "clear"), (11910, "stripe"),
]

lines = SRC.read_text().split("\n")


def banner_start(decl_line: int) -> int:
    """First comment line of the banner immediately above the decl (0-based)."""
    i = decl_line - 2  # line before the decl
    while i >= 0 and lines[i].strip() == "":
        i -= 1
    while i >= 0 and lines[i].strip().startswith("//"):
        i -= 1
    return i + 1


starts = [banner_start(d) for d, _ in EVENTS]
# Partition check: regions must be contiguous and cover starts[0]..EOF.
for k in range(len(EVENTS) - 1):
    assert starts[k] < starts[k + 1], f"regions overlap at {EVENTS[k][1]}/{EVENTS[k+1][1]}"
assert starts[0] > 0, "first region must not consume the primary's header"
print("boundaries:")
for (d, name), s in zip(EVENTS, starts):
    end = (starts[EVENTS.index((d, name)) + 1] - 1) if name != "stripe" else len(lines) - 1
    print(f"  {name:9s} decl@L{d}  region {s + 1}..{end + 1}  ({end - s + 1} lines)")

# Primary: header + shared infra (up to first region) + ~part declarations.
primary = lines[: starts[0]] + [""]
for _, name in EVENTS:
    primary.append(f"~part {name}")
primary.append("")
SRC.write_text("\n".join(primary) + ("\n" if primary[-1] != "" else ""))

for idx, (d, name) in enumerate(EVENTS):
    s = starts[idx]
    end = (starts[idx + 1] - 1) if idx + 1 < len(EVENTS) else len(lines) - 1
    body = lines[s : end + 1]
    header = [
        f"// Koru Standard Library: Reactive Stores — the `{name}` event.",
        f"// Joined via `~part {name}` in store.kz; merged into the store module at load.",
        "",
    ]
    Path(f"koru_std/store.{name}.kz").write_text("\n".join(header + body) + "\n")

print(f"\nprimary now {starts[0]} lines + 12 part declarations")
