#!/usr/bin/env python3
"""signal-vocabulary-stays-defined — every file under signals/ must be a
defined signal. A stub still carrying 'auto-registered orphan' fails.

The mint runs in commit-msg and writes the stub unstaged, so this check fires
on the commit AFTER a declaration created the orphan — the lag is one commit,
named in the manifest row rather than mistaken for a hole.

The drain convention (2026-09-26, 50 stubs → 0): a name history earned gets a
real definition in place; a semantic duplicate is tombstoned in place — the
file stays so register-on-miss cannot re-mint it, the note points at the
canonical, and membrane mirrors the canonical so belief-class aliases still
hit the garden-in-place interlock. A protocol token (acknowledged-none) is
marked never-a-signal. There is no fourth outcome — 'refine me' is not a
definition.
"""
import os
import sys

sigdir = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.abspath("../signals")
if not os.path.isdir(sigdir):
    print(f"BROKEN: signal directory not found: {sigdir}", file=sys.stderr)
    sys.exit(2)

orphans = []
for f in sorted(os.listdir(sigdir)):
    if not f.endswith(".signal"):
        continue
    try:
        if "auto-registered orphan" in open(os.path.join(sigdir, f)).read():
            orphans.append(f[:-7])
    except OSError:
        pass

if orphans:
    print(f"{len(orphans)} orphan signal(s) — stubs minted by register-on-miss, never refined:")
    for n in orphans:
        print(f"  {n}")
    print("each needs one of: a real definition (the name earned its place),")
    print("a tombstone folding it into a canonical (note points, membrane mirrors),")
    print("or a never-a-signal mark (protocol tokens). See the drain commit 4411a4d2d.")
    sys.exit(1)
print("all signal files defined — no orphans")
