#!/usr/bin/env python3
"""Split a koru_std module into `~part` files with explicit line ranges.

Config-driven twin of scripts/split_store.py, for modules whose regions are
not uniformly banner-bounded (list.kz's first event has no banner — the whole
header is its doc; grid.kz's events carry `=== NAME ===` banners).

The regions must partition [primary_lines+1, EOF] contiguously. The split is
byte-faithful: the primary + parts reconstruct the pre-split file exactly.

Run: python3 scripts/split_parts.py <module>   (config below)
"""
import sys
from pathlib import Path

# module -> (primary line count, [(part_name, start_line, end_line)])
# 1-based inclusive line numbers into the pre-split file.
CONFIG = {
    "list": (
        65,
        [
            ("new", 66, 200),    # new + new-i64
            ("push", 201, 227),  # push + push-i64
            ("len", 228, 247),   # len + len-i64
            ("get", 248, 273),   # get + get-i64
            ("pop", 274, 298),   # pop + pop-i64
            ("free", 299, None), # free + free-i64
        ],
    ),
    "grid": (
        466,
        [
            ("new", 467, 897),    # the GRID.NEW banner + decl + impl
            ("stored", 898, 1134),
            ("sweep", 1135, None),
        ],
    ),
}

mod = sys.argv[1]
if mod not in CONFIG:
    sys.exit(f"no config for {mod}; have: {', '.join(CONFIG)}")

primary_lines, parts = CONFIG[mod]
src = Path(f"koru_std/{mod}.kz")
lines = src.read_text().split("\n")

# Validate the partition is contiguous and covers [primary_lines+1, EOF].
prev = primary_lines
for name, start, end in parts:
    assert start == prev + 1, f"{name}: start {start} != prev+1 {prev + 1}"
    end = end if end is not None else len(lines)
    assert end >= start and end <= len(lines)
    prev = end
assert prev == len(lines), f"regions end at {prev}, file has {len(lines)}"

primary = lines[:primary_lines] + [""]
for name, _, _ in parts:
    primary.append(f"~part {name}")
primary.append("")
src.write_text("\n".join(primary) + "\n")

for name, start, end in parts:
    end = end if end is not None else len(lines)
    body = lines[start - 1 : end]
    header = [
        f"// Koru Standard Library: the `{name}` part of {mod}.kz.",
        f"// Joined via `~part {name}` in {mod}.kz; merged into the {mod} module at load.",
        "",
    ]
    Path(f"koru_std/{mod}.{name}.kz").write_text("\n".join(header + body) + "\n")

print(f"split {mod}.kz: primary {primary_lines} lines + {len(parts)} parts")
