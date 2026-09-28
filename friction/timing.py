#!/usr/bin/env python3
"""Per-session koruc timeline → refusal episodes → time-to-green per code.

An episode = a run of consecutive koruc calls whose output contains error[
terminated by a clean compile (or session end). Duration is wall-clock from
the first refusal to the terminating success — includes agent think time and
human idle, so report medians and compile counts alongside.
"""
import sqlite3, json, re, collections, statistics
from datetime import datetime

DB = "/Users/larsde/.local/share/devin/cli/sessions.db"
FAM = ("%koru%", "%kodot%", "%ogun%", "%orisha%", "%armored%", "%wartrain%", "%kopium%")

con = sqlite3.connect(DB)
sessions = con.execute(
    "SELECT id, working_directory FROM sessions WHERE " +
    " OR ".join(f"working_directory LIKE '{f}'" for f in FAM)).fetchall()

CALLID = re.compile(r'"(call_[a-zA-Z0-9#]+)"')
KORUC = re.compile(r'\bkoruc\b')
CODES = re.compile(r'error\[([A-Z]+\d+)\]')

def parse_t(s):
    try: return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
    except Exception: return None

episodes = []          # {session, cwd, codes, t0, t1, fails, resolved}
per_code_dwell = collections.defaultdict(list)
per_code_fails = collections.defaultdict(list)
all_dwell, unresolved = [], 0
timed_sessions = 0

for si, (sid, cwd) in enumerate(sessions):
    calls = {}
    for tid, tj, tuj in con.execute(
        "SELECT tool_call_id, tool_call_json, tool_call_update_json FROM tool_call_state WHERE session_id=?",
        (sid,)):
        if tj is None: continue
        try: j = json.loads(tj)
        except Exception: continue
        title = j.get("title", "")
        if not KORUC.search(title): continue
        upd = ""
        if tuj:
            try:
                uj = json.loads(tuj)
                for p in uj.get("content") or []:
                    c = p.get("content") or {}
                    if c.get("type") == "text": upd += c.get("text", "")
                    elif c.get("type") == "resource": upd += (c.get("resource") or {}).get("text", "")
            except Exception: upd = tuj
        calls[tid] = {"out": upd}

    if not calls: continue
    ts = {}
    for c, in con.execute(
        "SELECT chat_message FROM message_nodes WHERE session_id=? ORDER BY row_id", (sid,)):
        if "call_" not in c: continue
        try: m = json.loads(c)
        except Exception: continue
        t = parse_t((m.get("metadata") or {}).get("created_at") or "")
        if t is None: continue
        for tid in CALLID.findall(c):
            if tid in calls and tid not in ts: ts[tid] = t

    ev = sorted((ts[tid], CODES.findall(c["out"])) for tid, c in calls.items() if tid in ts)
    if not ev: continue
    timed_sessions += 1

    i = 0
    while i < len(ev):
        t, codes = ev[i]
        if not codes:
            i += 1; continue
        j = i
        bag = []
        fails = 0
        while j < len(ev) and ev[j][1]:
            bag += ev[j][1]; fails += 1; j += 1
        resolved = j < len(ev)
        if resolved:
            dur = ev[j][0] - t
            if 0 <= dur <= 7200:   # drop cross-day idle gaps
                eps_codes = sorted(set(bag))
                episodes.append({"session": sid, "cwd": cwd.split("/")[-1],
                                 "codes": eps_codes, "t0": ev[i][0],
                                 "dur_s": round(dur), "fails": fails})
                all_dwell.append(dur)
                for cd in eps_codes:
                    per_code_dwell[cd].append(dur)
                    per_code_fails[cd].append(fails)
            else:
                unresolved += 1
        else:
            unresolved += 1
        i = j + (1 if resolved else 0)

print(f"{timed_sessions} sessions with timed koruc calls, "
      f"{len(episodes)} resolved episodes, {unresolved} unresolved/>2h\n")

def med(xs): return statistics.median(xs) if xs else 0

rows = []
for cd in per_code_dwell:
    d, f = per_code_dwell[cd], per_code_fails[cd]
    rows.append((cd, len(d), med(d), med(f),
                 sum(d)/len(d)))
rows.sort(key=lambda r: -r[2]*r[1])

print(f"{'code':10} {'eps':>4} {'med dwell':>10} {'med fails':>10} {'mean dwell':>10}")
for cd, n, md, mf, mn in rows[:20]:
    print(f"{cd:10} {n:>4} {md/60:>8.1f}m {mf:>8.0f}x {mn/60:>8.1f}m")

print(f"\noverall: {len(all_dwell)} episodes, median dwell {med(all_dwell)/60:.1f} min, "
      f"mean {sum(all_dwell)/len(all_dwell)/60:.1f} min" if all_dwell else "none")

json.dump({"episodes": episodes,
           "per_code": {c: {"n": len(per_code_dwell[c]),
                            "med_dwell_s": med(per_code_dwell[c]),
                            "med_fails": med(per_code_fails[c]),
                            "mean_dwell_s": sum(per_code_dwell[c])/len(per_code_dwell[c])}
                        for c in per_code_dwell}},
          open("/Users/larsde/src/koru/friction/corpus-timing.json", "w"), indent=1)
print("wrote friction/corpus-timing.json")
