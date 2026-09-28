#!/usr/bin/env python3
"""friction — koru compiler-refusal corpus tool.

Verbs:
  scan                 rebuild corpus from Devin sessions.db (any cwd — a row
                       counts when the call invoked koru tooling, or the cwd
                       is koru-family)
  hist                 per-code histogram with teach-miss rates
  lookup <pattern>     occurrences of a code or message substring, with source
  pitfalls             ranked design/diagnostic backlog digest
  report               regenerate corpus.md (the corpus's own doc surface)

Every read verb takes filters:
  --without tok,tok    drop matching rows
  --only tok,tok       keep only matching rows
Tokens: org:NAME, repo:NAME, sess:NAME, cwd:SUBSTR — a bare token is a repo
substring. Example: `hist --without org:COCPORN,repo:ogun` is the systemic
view (compiler + mature consumers, no game-jam or site noise).
"""
import sqlite3, json, re, collections, sys, os, subprocess

DB = os.path.expanduser("~/.local/share/devin/cli/sessions.db")
CORPUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "corpus.json")
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "corpus.md")

# cwds where any tool output containing error[CODE] counts as corpus material
# even if the call didn't itself invoke the toolchain
FAM = ("%koru%", "%kodot%", "%ogun%", "%orisha%", "%armored%", "%wartrain%",
       "%kopium%")
# an invocation anywhere — the cwd allowlist is legacy; the compile is the event
KORU_CMD = re.compile(r"\bkoruc\b|\brun_regression\b")
# same project, moved: kodot/ wartrain work became ogun/wartrain
REPO_ALIAS = {"kodot": "ogun", "wartrain": "ogun"}
# dirs deleted since the session ran — resolved orgs by hand
ORG_GONE = {"kodot": "korulang"}

CALLID = re.compile(r'"(call_[a-zA-Z0-9#]+)"')
DIAG = re.compile(
    r"error\[([A-Z]+\d+)\]: ([^\n]+)\n\s*-->\s*([^\s:]+):(\d+):(\d+)(?:\n\s*\|\n\s*\d+\s*\|\s*(.*?)(?:\n|$))?", re.S)
DIAG_NOLINE = re.compile(r"error\[([A-Z]+\d+)\]: ([^\n]+?)(?:\n\s*-->\s*([^\s:]+):(\d+):(\d+))?(?:\n|$)")
HEDGE = re.compile(r'likely|probably|might|maybe|seems|guess|matching the proven|same pattern|safest|checking whether|test whether|isolat|not registering|workaround|try ', re.I)
RULE = re.compile(r'rule:|requires|must be|cannot|can.t|mandatory|only |koru (puns|requires)|confirmed', re.I)


def call_cmd(j):
    """Best-effort shell command for a tool call; None = undeterminable."""
    raw = j.get("rawInput") or {}
    if isinstance(raw.get("command"), str):
        return raw["command"]
    for p in j.get("content") or []:
        c = p.get("content") or {}
        res = c.get("resource") or {}
        if isinstance(res.get("text"), str):
            return res["text"]
    title = j.get("title") or ""
    return title if title.strip() else None


_org_cache = {}
def org_of(cwd):
    """GitHub org of the repo owning cwd, resolved from its own remote.
    'none' = repo has no origin (a measured answer); 'unknown' = the check
    itself failed — never silently labelled."""
    if cwd in _org_cache:
        return _org_cache[cwd]
    base = os.path.basename(cwd.rstrip("/")) or cwd
    if base in ORG_GONE:
        org = ORG_GONE[base]
    elif not os.path.isdir(cwd):
        org = "gone"
    else:
        try:
            p = subprocess.run(["git", "-C", cwd, "remote", "get-url", "origin"],
                               capture_output=True, text=True, timeout=5)
            m = re.search(r"github\.com[:/]([^/]+)/", p.stdout.strip())
            org = m.group(1) if m else ("local-remote" if p.stdout.strip() else "none")
        except Exception:
            org = "unknown"
    _org_cache[cwd] = org
    return org


def repo_of(cwd):
    base = os.path.basename(cwd.rstrip("/")) or cwd
    return REPO_ALIAS.get(base, base)


def scan():
    con = sqlite3.connect(DB)
    sessions = con.execute(
        "SELECT id, working_directory FROM sessions").fetchall()
    all_rows = []
    skipped_cmd = 0
    for sid, cwd in sessions:
        fam = any(re.sub(r"%", "", f) in cwd for f in FAM)
        calls = {}
        for tid, tj, tuj in con.execute(
            "SELECT tool_call_id, tool_call_json, tool_call_update_json FROM tool_call_state WHERE session_id=?", (sid,)):
            if tj is None: continue
            try: j = json.loads(tj)
            except Exception: continue
            cmd = call_cmd(j)
            if cmd is None and not fam:
                skipped_cmd += 1
                continue
            invoked = bool(cmd and KORU_CMD.search(cmd))
            if not (fam or invoked): continue
            via = "koruc" if re.search(r"\bkoruc\b", cmd or "") else \
                  "board" if invoked else "ambient"
            upd = ""
            if tuj:
                try:
                    uj = json.loads(tuj)
                    for p in uj.get("content") or []:
                        c = p.get("content") or {}
                        if c.get("type") == "text": upd += c.get("text", "")
                        elif c.get("type") == "resource": upd += (c.get("resource") or {}).get("text", "")
                except Exception: upd = tuj
            calls[tid] = {"out": upd, "via": via}
        if not calls: continue
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
        for tid, call in calls.items():
            out = call["out"]
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
                                 "src": src.strip()[:140], "after": after,
                                 "taught": taught, "via": call["via"],
                                 "repo": repo_of(cwd), "org": org_of(cwd)})
    json.dump(all_rows, open(CORPUS, "w"), indent=1)
    print(f"{len(all_rows)} diagnostics across {len(set(r['session'] for r in all_rows))} sessions -> {CORPUS}")
    by_repo = collections.Counter(r["repo"] for r in all_rows)
    print("repos:", "  ".join(f"{k}={v}" for k, v in by_repo.most_common()))
    by_org = collections.Counter(r["org"] for r in all_rows)
    print("orgs: ", "  ".join(f"{k}={v}" for k, v in by_org.most_common()))
    if skipped_cmd:
        print(f"note: {skipped_cmd} non-family calls had no determinable "
              f"command and were skipped — visible, not silent")


def load():
    if not os.path.exists(CORPUS):
        sys.exit(f"no corpus at {CORPUS} — run `friction scan` first")
    return json.load(open(CORPUS))


def _match(row, tok):
    key, _, val = tok.partition(":")
    if not val:
        return key in row["repo"]
    if key == "org":  return val.lower() == row["org"].lower()
    if key == "repo": return val.lower() in row["repo"].lower()
    if key == "sess": return val.lower() in row["session"].lower()
    if key == "cwd":  return val.lower() in row["cwd"].lower()
    if key == "via":  return val == row.get("via")
    sys.exit(f"unknown filter key '{key}' — use org:/repo:/sess:/cwd:/via:")


def filtered(rows, args):
    without, only = [], []
    i = 0
    while i < len(args):
        if args[i] == "--without": without += args[i + 1].split(","); i += 2
        elif args[i] == "--only": only += args[i + 1].split(","); i += 2
        else: i += 1
    if only:
        rows = [r for r in rows if any(_match(r, t) for t in only)]
    if without:
        rows = [r for r in rows if not any(_match(r, t) for t in without)]
    return rows


def hist(*args):
    rows = filtered(load(), list(args))
    if not rows: return print("no rows after filter")
    by = collections.Counter(r["code"] for r in rows)
    tm = collections.Counter(r["code"] for r in rows if r["taught"] == "teach-miss")
    for code, n in by.most_common():
        print(f"{code:10} {n:5} ({100*n/len(rows):4.1f}%)  teach-miss {tm[code]}")
    repos = collections.Counter(r["repo"] for r in rows)
    print(f"\n{len(rows)} rows — repos: " + "  ".join(f"{k}={v}" for k, v in repos.most_common()))


def lookup(pat, *args):
    rows = filtered(load(), list(args))
    hits = [r for r in rows if pat.lower() in (r["code"] + " " + r["msg"]).lower()]
    print(f"{len(hits)} occurrences of '{pat}'")
    for r in hits[:40]:
        loc = f"{r['file']}:{r['line']}".rstrip(":")
        print(f"\n[{r['session'][:16]} {r['repo']}] {r['t'][5:16] or '?'} {r['code']} {loc}")
        print(f"  {r['msg'][:130]}")
        if r["src"]: print(f"  src: {r['src'][:110]}")
        if r["after"]: print(f"  then: {r['after'][:120]}")
        if r["taught"] == "teach-miss": print("  ** TEACH-MISS: agent guessed after this")


def pitfalls(*args):
    rows = filtered(load(), list(args))
    by = collections.Counter((r["code"], r["msg"][:60]) for r in rows)
    tm = collections.Counter((r["code"], r["msg"][:60]) for r in rows if r["taught"] == "teach-miss")
    print("# Typical pitfalls (generated from session refusals)\n")
    for (code, msg), n in by.most_common(30):
        miss = f" — teach-miss {tm[(code,msg)]}×" if tm[(code,msg)] else ""
        ex = next(r for r in rows if r["code"] == code and r["msg"].startswith(msg[:30]))
        print(f"## {code} ×{n}{miss}\n{msg}\nexemplar: `{ex['file']}:{ex['line']}` `{ex['src'][:80]}`\n")


def report(*args):
    rows = load()
    systemic = filtered(rows, ["--without", "org:COCPORN,repo:ogun"])
    lines = ["# Koru friction — corpus histogram\n"]
    for tag, view in (("all rows", rows), ("systemic view — `org:COCPORN,repo:ogun` excluded", systemic)):
        if not view: continue
        by = collections.Counter(r["code"] for r in view)
        tm = collections.Counter(r["code"] for r in view if r["taught"] == "teach-miss")
        repos = collections.Counter(r["repo"] for r in view)
        sess = len(set(r["session"] for r in view))
        lines.append(f"\n## {tag}\n\n{len(view)} diagnostics · {sess} sessions\n")
        lines.append("Per-repo rows: " + ", ".join(f"{k}={v}" for k, v in repos.most_common()) + "\n")
        lines.append("| code | n | share | teach-miss |\n|---|---|---|---|")
        for code, n in by.most_common():
            lines.append(f"| {code} | {n} | {100*n/len(view):.1f}% | {tm[code]} |")
    open(REPORT, "w").write("\n".join(lines) + "\n")
    print(f"wrote {REPORT}")


VERBS = {"scan": scan, "hist": hist, "lookup": lookup, "pitfalls": pitfalls,
         "report": report}
if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in VERBS:
        sys.exit(__doc__)
    v = sys.argv[1]
    VERBS[v](*sys.argv[2:]) if sys.argv[2:] else VERBS[v]()
