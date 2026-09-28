#!/usr/bin/env python3
"""friction — koru compiler-refusal corpus tool.

Verbs:
  scan                 rebuild corpus from Devin sessions.db (koru-family cwds)
  hist                 per-code histogram with teach-miss rates
  lookup <pattern>     occurrences of a code or message substring, with source
  pitfalls             ranked design/diagnostic backlog digest
"""
import sqlite3, json, re, collections, sys, os

DB = os.path.expanduser("~/.local/share/devin/cli/sessions.db")
CORPUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "corpus.json")
FAM = ("%koru%", "%kodot%", "%ogun%", "%orisha%", "%armored%", "%wartrain%", "%kopium%")

CALLID = re.compile(r'"(call_[a-zA-Z0-9#]+)"')
DIAG = re.compile(
    r"error\[([A-Z]+\d+)\]: ([^\n]+)\n\s*-->\s*([^\s:]+):(\d+):(\d+)(?:\n\s*\|\n\s*\d+\s*\|\s*(.*?)(?:\n|$))?", re.S)
DIAG_NOLINE = re.compile(r"error\[([A-Z]+\d+)\]: ([^\n]+?)(?:\n\s*-->\s*([^\s:]+):(\d+):(\d+))?(?:\n|$)")
HEDGE = re.compile(r'likely|probably|might|maybe|seems|guess|matching the proven|same pattern|safest|checking whether|test whether|isolat|not registering|workaround|try ', re.I)
RULE = re.compile(r'rule:|requires|must be|cannot|can.t|mandatory|only |koru (puns|requires)|confirmed', re.I)


def scan():
    con = sqlite3.connect(DB)
    sessions = con.execute(
        "SELECT id, working_directory FROM sessions WHERE " +
        " OR ".join(f"working_directory LIKE '{f}'" for f in FAM)).fetchall()
    all_rows = []
    for sid, cwd in sessions:
        calls = {}
        for tid, tj, tuj in con.execute(
            "SELECT tool_call_id, tool_call_json, tool_call_update_json FROM tool_call_state WHERE session_id=?", (sid,)):
            if tj is None: continue
            try: j = json.loads(tj)
            except Exception: continue
            upd = ""
            if tuj:
                try:
                    uj = json.loads(tuj)
                    for p in uj.get("content") or []:
                        c = p.get("content") or {}
                        if c.get("type") == "text": upd += c.get("text", "")
                        elif c.get("type") == "resource": upd += (c.get("resource") or {}).get("text", "")
                except Exception: upd = tuj
            calls[tid] = upd
        ts, assistants = {}, []
        for c, in con.execute(
            "SELECT chat_message FROM message_nodes WHERE session_id=? ORDER BY row_id", (sid,)):
            try: m = json.loads(c)
            except Exception: continue
            t = (m.get("metadata") or {}).get("created_at") or ""
            if "call_" in c:
                for tid in CALLID.findall(c):
                    if tid in calls and tid not in ts: ts[tid] = t
            if m.get("role") == "assistant" and isinstance(m.get("content"), str) and m["content"].strip():
                assistants.append((t, m["content"].strip()))
        assistants.sort()
        def nxt(t):
            for at, ac in assistants:
                if at > t: return ac[:200]
            return ""
        for tid, out in calls.items():
            if "error[" not in out: continue
            t = ts.get(tid, "")
            seen = set()
            for d in (DIAG.findall(out) or DIAG_NOLINE.findall(out)):
                code, msg, f, ln, col = d[:5]
                src = (d[5] if len(d) > 5 else "") or ""
                if (code, msg, f, ln) in seen: continue
                seen.add((code, msg, f, ln))
                after = nxt(t)
                taught = ("teach-miss" if (after and HEDGE.search(after))
                          else "rule-learned" if RULE.search(after) else "other")
                all_rows.append({"session": sid, "cwd": cwd, "t": t, "code": code,
                                 "msg": msg.strip(), "file": f, "line": ln,
                                 "src": src.strip()[:140], "after": after, "taught": taught})
    json.dump(all_rows, open(CORPUS, "w"), indent=1)
    print(f"{len(all_rows)} diagnostics across {len(set(r['session'] for r in all_rows))} sessions -> {CORPUS}")


def load():
    if not os.path.exists(CORPUS):
        sys.exit(f"no corpus at {CORPUS} — run `friction scan` first")
    return json.load(open(CORPUS))


def hist():
    rows = load()
    by = collections.Counter(r["code"] for r in rows)
    tm = collections.Counter(r["code"] for r in rows if r["taught"] == "teach-miss")
    for code, n in by.most_common():
        print(f"{code:10} {n:5} ({100*n/len(rows):4.1f}%)  teach-miss {tm[code]}")


def lookup(pat):
    rows = load()
    hits = [r for r in rows if pat.lower() in (r["code"] + " " + r["msg"]).lower()]
    print(f"{len(hits)} occurrences of '{pat}'")
    for r in hits[:40]:
        loc = f"{r['file']}:{r['line']}".rstrip(":")
        print(f"\n[{r['session'][:16]}] {r['t'][5:16] or '?'} {r['code']} {loc}")
        print(f"  {r['msg'][:130]}")
        if r["src"]: print(f"  src: {r['src'][:110]}")
        if r["after"]: print(f"  then: {r['after'][:120]}")
        if r["taught"] == "teach-miss": print("  ** TEACH-MISS: agent guessed after this")


def pitfalls():
    rows = load()
    by = collections.Counter((r["code"], r["msg"][:60]) for r in rows)
    tm = collections.Counter((r["code"], r["msg"][:60]) for r in rows if r["taught"] == "teach-miss")
    print("# Typical pitfalls (generated from session refusals)\n")
    for (code, msg), n in by.most_common(30):
        miss = f" — teach-miss {tm[(code,msg)]}×" if tm[(code,msg)] else ""
        ex = next(r for r in rows if r["code"] == code and r["msg"].startswith(msg[:30]))
        print(f"## {code} ×{n}{miss}\n{msg}\nexemplar: `{ex['file']}:{ex['line']}` `{ex['src'][:80]}`\n")


VERBS = {"scan": scan, "hist": hist, "lookup": lookup, "pitfalls": pitfalls}
if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in VERBS:
        sys.exit(__doc__)
    v = sys.argv[1]
    VERBS[v](*sys.argv[2:]) if sys.argv[2:] else VERBS[v]()
