#!/usr/bin/env python3
"""obligation_fuzz.py — scoped mutation fuzzing for obligation tracking.

Roadmap item 2: move discharges across scope boundaries instead of
splicing syntax. The mutation space is semantic — where an obligation is
consumed, re-fed, or dropped relative to `@`-edges, `[@scope]` marks, and
effect-body boundaries — not structural.

Mutants land in `.kfuzz/oblfuzz/` (gitignored scratch). For each mutant:
`koruc -c` (shape layer) then `koruc` (coordination/backend). The verdict
matrix separates the layers so a mutant that is semantically hostile but
accepted anywhere past the expected wall is a finding, not a test failure.

Operators:
    refeed-stale      @L(x: v) routes an OUTER binding instead of the
                      arm's payload binding — re-feeds a stale/dead slot
    drop-at-arg       @L(a: x, b: y) -> @L(a: x) — partial reseed
    double-dispatch   | arm b |> consume(h: b) |> @L(h: b) — use-after-
                      discharge then re-feed (KORU030 expected)
    arm-end-consume   | arm b |> @L(...) -> | arm b |> consume(h: b) —
                      the fold's continuation never runs; live obligations
                      at arm end are the wall under test
    scope-toggle      | arm b |> <-> | arm b[@scope] |> — twin-wall
                      agreement between checker and auto-discharge inserter

Usage:
    python scripts/obligation_fuzz.py            # all seeds, all ops
    python scripts/obligation_fuzz.py --seed 330_074 --op refeed-stale
"""
import argparse
import glob
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KORUC = os.path.join(REPO, "zig-out", "bin", "koruc")
OUT = os.path.join(REPO, ".kfuzz", "oblfuzz")

SEED_GLOBS = [
    os.path.join(REPO, "tests", "regression", "300_ADVANCED_FEATURES",
                 "330_PHANTOM_TYPES", "330_0[7-8]*", "input.kz"),
    os.path.join(REPO, "fuzz", "repros", "probe_nested_*.kz"),
]

AT_EDGE = re.compile(r"@(\w+)\(([^)]*)\)")
ARM = re.compile(r"^(\s*)\| (\w+) (\w+)(\[@scope\])? \|> (.*)$",
                 re.MULTILINE)
OWNED_TOR = re.compile(r"~tor (\w+)\s*{([^}]*)}")
_COMMENT = re.compile(r"//[^\n]*")


def _mask(src):
    """Comments blanked to spaces (length-preserving): regex offsets computed
    over the mask slice the real source correctly, so an operator can never
    land inside a doc comment that quotes the fold's own shape."""
    return _COMMENT.sub(lambda m: " " * len(m.group(0)), src)


def owned_consumers(src):
    """Terminal dischargers: tors taking a <!owned> param whose decl block
    lists no outcome handing an owned handle back (folds like `spin` carry
    owned params but are not discharges)."""
    out = []
    for m in OWNED_TOR.finditer(_mask(src)):
        name, params = m.group(1), m.group(2)
        block_end = src.find("~", m.end())
        block = src[m.end():block_end if block_end > 0 else len(src)]
        if "<owned!>" in block:          # outcome returns ownership — carrier
            continue
        for p in params.split(","):
            if "<!owned>" in p:
                out.append((name, p.split(":")[0].strip()))
    return out


def _first_outer_binding(src):
    """A plausible stale binding: the one produced before the first fold —
    e.g. `make(): h0 |>` -> `h0`."""
    m = re.search(r"\(\)\s*:\s*(\w+)\s*\|>", src)
    return m.group(1) if m else None


def mut_refeed_stale(src):
    stale = _first_outer_binding(_mask(src))
    if not stale:
        return []
    out = []
    for m in AT_EDGE.finditer(_mask(src)):
        args = m.group(2)
        for part in args.split(","):
            if ":" not in part:
                continue
            k, v = part.split(":", 1)
            if v.strip() != stale and k.strip():
                new = (src[:m.start(2)]
                       + args.replace(part, f"{k.strip()}: {stale}", 1)
                       + src[m.end(2):])
                out.append((f"refeed-stale({m.group(1)}.{k.strip()}={stale})",
                            new))
    return out


def mut_drop_at_arg(src):
    out = []
    for m in AT_EDGE.finditer(_mask(src)):
        args = [a for a in m.group(2).split(",") if ":" in a]
        if len(args) < 2:
            continue
        for i, a in enumerate(args):
            keep = [x for j, x in enumerate(args) if j != i]
            new = (src[:m.start(2)] + ", ".join(keep) + src[m.end(2):])
            dropped = a.split(":")[0].strip()
            out.append((f"drop-at-arg({m.group(1)}.{dropped})", new))
    return out


def _mutate_arm(src, transform):
    out = []
    for m in ARM.finditer(_mask(src)):
        indent, arm, bind, scope, rhs = m.groups()
        hit = transform(indent, arm, bind, scope, rhs, m)
        if hit:
            out.append(hit)
    return out


def mut_double_dispatch(src):
    consumers = owned_consumers(src)
    out = []
    for cname, cfield in consumers:
        def t(indent, arm, bind, scope, rhs, m,
              cname=cname, cfield=cfield):
            if not rhs.strip().startswith("@"):
                return None
            nr = (f"{cname}({cfield}: {bind}) "
                  f"|> {rhs.strip()}")
            line = f"{indent}| {arm} {bind}{scope or ''} |> {nr}"
            new = src[:m.start()] + line + src[m.end():]
            return (f"double-dispatch({cname} before @{rhs.strip()[:12]})",
                    new)
        out += _mutate_arm(src, t)
    return out


def mut_arm_end_consume(src):
    consumers = owned_consumers(src)
    out = []
    for cname, cfield in consumers:
        def t(indent, arm, bind, scope, rhs, m,
              cname=cname, cfield=cfield):
            if not rhs.strip().startswith("@"):
                return None
            line = (f"{indent}| {arm} {bind}{scope or ''} "
                    f"|> {cname}({cfield}: {bind})")
            new = src[:m.start()] + line + src[m.end():]
            return (f"arm-end-consume({cname} drops @{rhs.strip()[:12]})",
                    new)
        out += _mutate_arm(src, t)
    return out


def mut_scope_toggle(src):
    def t(indent, arm, bind, scope, rhs, m):
        if scope:
            new_scope = ""
            tag = "remove"
        else:
            new_scope = "[@scope]"
            tag = "add"
        line = f"{indent}| {arm} {bind}{new_scope} |> {rhs}"
        new = src[:m.start()] + line + src[m.end():]
        return (f"scope-toggle({tag} on |{arm} {bind})", new)
    return _mutate_arm(src, t)


OPS = {
    "refeed-stale": mut_refeed_stale,
    "drop-at-arg": mut_drop_at_arg,
    "double-dispatch": mut_double_dispatch,
    "arm-end-consume": mut_arm_end_consume,
    "scope-toggle": mut_scope_toggle,
}


# ------------------------------------------------------------------ verdicts

_ENV = dict(os.environ)
_ENV["PATH"] = "/home/cypoe/tools/zig-0.15.1:" + _ENV.get("PATH", "")
_ENV["ZIG_LOCAL_CACHE_DIR"] = "/home/cypoe/zigcache/local"
_ENV["ZIG_GLOBAL_CACHE_DIR"] = "/home/cypoe/zigcache/global"


def koruc(path, check_only, timeout=120):
    cmd = [KORUC, "-c", path] if check_only else [KORUC, path]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=timeout, cwd=REPO, env=_ENV)
    except subprocess.TimeoutExpired:
        return "TIMEOUT", ""
    out = (r.stdout + r.stderr).strip()
    m = re.search(r"(KORU\d+)", out)
    if r.returncode == 0:
        return "GREEN", out[-200:]
    return (m.group(1) if m else f"rc{r.returncode}"), out[-300:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", default=None, help="substring match")
    ap.add_argument("--op", default=None, choices=list(OPS))
    ap.add_argument("--full", action="store_true",
                    help="also run full koruc on -c-green mutants")
    args = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)
    seeds = []
    for g in SEED_GLOBS:
        seeds += glob.glob(g)
    if args.seed:
        seeds = [s for s in seeds if args.seed in s]
    print(f"{len(seeds)} seeds")

    rows = []
    for seed in seeds:
        src = open(seed, encoding="utf-8", errors="replace").read()
        sname = os.path.basename(os.path.dirname(seed)) \
            if os.path.basename(seed) == "input.kz" \
            else os.path.basename(seed)
        ops = [args.op] if args.op else list(OPS)
        for opname in ops:
            for mi, (desc, msrc) in enumerate(OPS[opname](src)):
                mname = f"{sname}__{mi:02d}_{desc.replace(' ', '_')[:60]}.kz"
                mname = re.sub(r"[^A-Za-z0-9_.()\[\]-]", "_", mname)
                mpath = os.path.join(OUT, mname)
                open(mpath, "w").write(msrc)
                v, detail = koruc(mpath, check_only=True)
                full = ""
                if v == "GREEN" and args.full:
                    fv, fdet = koruc(mpath, check_only=False)
                    full = f" full={fv}"
                    if fv != "GREEN":
                        detail += " | " + fdet
                rows.append((sname, desc, v, full, detail))
                print(f"{v:12s}{full:14s} {sname} :: {desc}")
    print(f"\n{len(rows)} mutants; verdicts:")
    tally = {}
    for _s, _d, v, f, _det in rows:
        k = v + ("/" + f.strip() if f else "")
        tally[k] = tally.get(k, 0) + 1
    for k, n in sorted(tally.items()):
        print(f"  {n:4d} {k}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
