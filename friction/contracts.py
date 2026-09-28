#!/usr/bin/env python3
"""contracts.py — generate docs/refusal-matrix.md: every refusal the stdlib
can emit, grouped by the contract it defends and ranked by how often it has
actually fired in session telemetry.

The contract a transform refuses on is enumerable — each refusal site in
koru_std/*.kz carries its message template. Agents otherwise learn the
surface serially (measured: one std/supervisor session paid 5–11 min per
refusal, discovering the policy grammar one clause at a time). This doc is
a pure projection of the refusal sites plus corpus volume — it cannot drift
unless the sites do. Regenerate: python3 friction/contracts.py
"""
import re, json, os, sys, glob, collections, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KORU_STD = os.path.join(ROOT, "koru_std")
CORPUS = os.path.join(ROOT, "friction", "corpus.json")
OUT = os.path.join(ROOT, "docs", "refusal-matrix.md")

# refusal( ... , .KORU161, <loc args>, "message", .{args} ) — the message is
# the first string literal after the diagnostic code inside the call.
SITE = re.compile(
    r'refus(?:e|al)\s*\([^;]*?\.(KORU\d+|PARSE\d+|SHAPE\d+|E\d+)\s*,[^;]*?'
    r'"((?:[^"\\]|\\.)*)"',
    re.S,
)
PREFIX = re.compile(r'^(std/[a-z_]+(?::[a-z_-]+)?)')


def extract():
    sites = []
    for path in sorted(glob.glob(os.path.join(KORU_STD, "*.kz"))):
        text = open(path).read()
        for code, msg in SITE.findall(text):
            msg = msg.replace("\\n", " ").replace('\\"', '"')
            m = PREFIX.match(msg)
            contract = m.group(1) if m else "(unprefixed)"
            sites.append({"code": code, "contract": contract,
                          "msg": msg, "file": os.path.basename(path)})
    return sites


def corpus_counts():
    """contract prefix -> measured refusal count, from corpus.json if it exists."""
    if not os.path.exists(CORPUS):
        return None
    rows = json.load(open(CORPUS))
    counts = collections.Counter()
    for r in rows:
        m = PREFIX.match(r["msg"])
        if m:
            counts[m.group(1)] += 1
    return counts


def main():
    sites = extract()
    dedup = {}
    for s in sites:
        dedup.setdefault((s["code"], s["msg"]), s)
    sites = list(dedup.values())

    counts = corpus_counts()
    groups = collections.defaultdict(list)
    for s in sites:
        groups[s["contract"]].append(s)

    def pain(g):
        return counts.get(g, 0) if counts else 0

    head = subprocess.run(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True).stdout.strip()

    out = ["# The Refusal Matrix\n",
           "Every refusal the stdlib contracts can emit — a pure projection of the\n",
           "`refuse(`/`refusal(` sites in `koru_std/*.kz`, grouped by contract and\n",
           "ranked by measured volume in `friction/corpus.json`. **Do not edit by\n",
           "hand** — run `python3 friction/contracts.py`.\n",
           f"\nSnapshot: `{head}` · {len(sites)} refusal sites\n"]
    if counts is None:
        out.append("\n> corpus.json not found — run `friction.py scan` to rank "
                   "contracts by measured volume; ordering below is alphabetical.\n")

    for contract in sorted(groups, key=lambda g: (-pain(g), g)):
        items = groups[contract]
        vol = counts.get(contract, 0) if counts else 0
        vol_note = f" — fired {vol}× in the corpus" if counts is not None else ""
        out.append(f"\n## `{contract}` ({len(items)} refusals{vol_note})\n")
        for s in sorted(items, key=lambda s: s["msg"]):
            out.append(f"- `{s['code']}` {s['msg']}\n")

    open(OUT, "w").write("".join(out))
    measured = sum(1 for s in sites if counts and counts.get(s["contract"]))
    print(f"{len(sites)} unique refusal sites -> {OUT}")
    print(f"{len(groups)} contracts; {measured} sites sit under measured-refusal contracts")


if __name__ == "__main__":
    main()
