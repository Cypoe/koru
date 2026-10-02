#!/usr/bin/env python3
"""holonomic_gate.py — certificate-backed equality for Koru label-folds.

Consumes the canonical corpus fold shape:

    tor step { n: i64, acc: i64 }
    | more { n: i64, acc: i64 }
    | done i64

    step = if(n > 0)
    | then => more { n: n - 1, acc: acc + n }
    | else => done acc

    run = #L step(n: start, acc: 0)
    | more s |> @L(s.n, s.acc)
    | done e -> e

The state tuple is a coupled first-order recurrence system. Two exact
verification paths, in order:

  1. CLOSED FORM — every update affine in the state tuple gives
     s_{n+1} = M s_n + v, and sympy's symbolic M^n makes the observed
     trajectory a closed-form expression in n. Certificates verify as
     residual identities in n; equality is a closed-form diff.
  2. GENERIC-STATE RESIDUAL — certificates whose identity holds for all
     states (e.g. factorial's a_{n+1} = (n+2)*a_n telescopes on the
     counter-index relation) verify by substituting F^i over a generic
     state with affine counters pinned to init + c*n.

Certificates themselves are fitted by undetermined coefficients over QQ
(bounded order/degree search — "not found within bounds" is a result,
never a refutation). Everything else gets a structured REFUSED.

Modes:
    cert FILE            fit + verify a P-recurrence for the observed field
    equal FILE_A FILE_B  certified equality of the two observed fields

Verdicts: CERTIFIED / EQUAL / NOT-EQUAL / CANDIDATE / REFUSED:<why> /
NOT-FOUND-WITHIN-BOUNDS. Requires sympy (host python).
"""
import os
import re
import sys
from dataclasses import dataclass

import sympy as sp

N = sp.Symbol("__n", integer=True)   # iterate index (never a state name)


class Refused(Exception):
    pass


# ---------------------------------------------------------------- extraction

@dataclass
class Fold:
    step_name: str
    params: list                 # ordered state field names
    guard: tuple                 # (field, op, rhs) — continues while true
    updates: dict                # field -> sympy expr over state syms
    init: dict                   # field -> int
    observe: str                 # field whose trajectory is compared


_ARITH = re.compile(r"^[A-Za-z_@][A-Za-z0-9_@.() \t+\-*/%]*$")


def _split_top(s: str):
    """Split on top-level commas only — commas inside @builtin(...) calls
    belong to the expression."""
    out, depth, cur = [], 0, []
    for ch in s:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    if cur:
        out.append("".join(cur))
    return out


def _to_sympy(expr: str, env: dict):
    """Koru arithmetic expr -> sympy. Refuse anything outside the subset."""
    e = expr.strip()
    e = re.sub(r"@as\([^,]+,\s*", "", e)          # @as(T, x) -> x)
    e = re.sub(r"@intCast\(", "(", e)
    e = re.sub(r"@intFromBool\(", "(", e)
    e = re.sub(r"@divTrunc\(([^,]+),([^)]+)\)", r"(\1)//(\2)", e)
    e = re.sub(r"@mod\(([^,]+),([^)]+)\)", r"(\1)%(\2)", e)
    e = re.sub(r"[ \t]+\)", ")", e)
    if e.count("(") != e.count(")"):
        raise Refused(f"unbalanced after builtin rewrite: {expr!r}")
    if not _ARITH.match(e):
        raise Refused(f"non-arithmetic expression: {expr!r}")
    try:
        out = sp.sympify(e, locals=env, rational=True)
    except Exception:
        raise Refused(f"expression outside arithmetic subset: {expr!r}")
    if out.free_symbols - set(env.values()):
        raise Refused(f"free names outside state fields: {expr!r}")
    return out


def extract_fold(src: str, label: str = "") -> Fold:
    src = "\n".join(ln.split("//")[0] for ln in src.splitlines())

    m = re.search(r"#(\w+)\s+(\w+)\(([^)]*)\)", src)
    if not m:
        raise Refused("no #L step(...) fold found")
    lab, step_name, init_args = m.groups()
    if label and label != lab:
        raise Refused(f"fold #{label} not found (found #{lab})")

    pm = re.search(rf"tor {step_name}\s*{{([^}}]*)}}", src)
    if not pm:
        raise Refused(f"step tor {step_name} decl not found")
    params = [p.split(":")[0].strip() for p in pm.group(1).split(",") if p.strip()]

    # continue-arm update record: `=> <br> { f: e, ... }`
    um = re.search(r"=>\s*\w+\s*{([^}]*)}", src)
    if not um:
        raise Refused("no {f: e, ...} update record in continue arm")
    raw_updates = {}
    for kv in _split_top(um.group(1)):
        if ":" in kv:
            f, e = kv.split(":", 1)
            raw_updates[f.strip()] = e.strip()

    # guard: `step = if(<cond>)` — single comparison or none
    gm = re.search(rf"{step_name}\s*=\s*if\(([^)]*)\)", src)
    guard = None
    if gm:
        gm2 = re.match(r"\s*(\w+)\s*(<=|>=|!=|==|<|>)\s*(-?\w+)", gm.group(1))
        if gm2:
            guard = (gm2.group(1), gm2.group(2), gm2.group(3))

    # init args from `#L step(n: start, acc: 0)`; free names resolved via the
    # concrete call site `entry(param: lit)` found anywhere in the file
    named = {}
    for a in init_args.split(","):
        if ":" in a:
            k, v = a.split(":", 1)
            named[k.strip()] = v.strip()
    callers = dict(re.findall(r"(\w+)\s*:\s*(-?\d+)", src))
    init = {}
    for p in params:
        v = named.get(p, "")
        if re.fullmatch(r"-?\d+", v or ""):
            init[p] = int(v)
        elif v in callers:
            init[p] = int(callers[v])
        else:
            raise Refused(f"unresolved init for field {p}: {v!r}")

    env = {p: sp.Symbol(p) for p in params}
    updates = {f: _to_sympy(e, env) for f, e in raw_updates.items()}

    dm = re.search(r"=>\s*done\s+(\w+)", src)
    obs = dm.group(1) if dm and dm.group(1) in params else params[-1]

    return Fold(step_name, params, guard, updates, init, obs)


# ------------------------------------------------------------- trajectory

_OPS = {"<": lambda a, b: a < b, ">": lambda a, b: a > b,
        "<=": lambda a, b: a <= b, ">=": lambda a, b: a >= b,
        "==": lambda a, b: a == b, "!=": lambda a, b: a != b}


def trajectory(fold: Fold, steps: int):
    """Iterate the transition numerically: observed post-update values."""
    state = dict(fold.init)
    out = []
    for _ in range(steps):
        if fold.guard:
            f, op, rhs = fold.guard
            if rhs in state:
                rv = state[rhs]
            elif re.fullmatch(r"-?\d+", rhs):
                rv = int(rhs)
            else:
                raise Refused(f"guard rhs not resolvable: {rhs!r}")
            if not _OPS[op](state[f], rv):
                break
        nxt = {}
        for f in fold.params:
            e = fold.updates.get(f, sp.Symbol(f))
            v = e.subs(state)
            if not v.is_number:
                raise Refused(f"non-numeric update for {f}: {v}")
            nxt[f] = sp.Integer(v)
        out.append(nxt[fold.observe])
        state = nxt
    return out


# --------------------------------------------------------------- certificates

def candidate_certs(seq, max_order=4, max_degree=4):
    """Yield (order, [p_i]) candidate certificates satisfying
    sum_i p_i(n) a_{n+i} = 0 on the sampled window — nullspace vectors of
    the undetermined-coefficients system, p_i deg<=max_degree over QQ."""
    for order in range(1, max_order + 1):
        for deg in range(0, max_degree + 1):
            ncoeffs = (order + 1) * (deg + 1)
            if len(seq) < order + ncoeffs + 2:
                continue
            rows = []
            for t in range(len(seq) - order):
                rows.append([seq[t + i] * t**j
                             for i in range(order + 1)
                             for j in range(deg + 1)])
            for vec in sp.Matrix(rows).nullspace():
                polys = [sum(sp.nsimplify(vec[i * (deg + 1) + j]) * N**j
                             for j in range(deg + 1))
                         for i in range(order + 1)]
                yield order, polys


def cert_str(order, polys):
    return " + ".join(f"({sp.sstr(p)})*a[n+{i}]"
                      for i, p in enumerate(polys)) + " = 0"


# ------------------------------------------------------------------ verify

def _affine_counters(fold: Fold):
    """Fields updated as x -> x + c (c int): value at index n is init + c*n."""
    out = {}
    for f in fold.params:
        e = fold.updates.get(f)
        if e is None:
            continue
        d = sp.simplify(e - sp.Symbol(f))
        if d.is_Integer:
            out[f] = int(d)
    return out


def closed_form(fold: Fold):
    """Observed post-update value as a closed-form expr in N, when every
    update is affine in the full state tuple (s_{n+1} = M s_n + v ->
    s_n = T^n s'_0 over the augmented system). Returns None otherwise."""
    P = [sp.Symbol(p) for p in fold.params]
    dim = len(P)
    rows = []
    for f in fold.params:
        e = sp.expand(fold.updates.get(f, sp.Symbol(f)))
        try:
            if sp.Poly(e, *P).total_degree() > 1:
                return None
        except Exception:                    # floor/mod/etc: not polynomial
            return None
        row = [sp.diff(e, s) for s in P]
        const = sp.simplify(e - sum(r * s for r, s in zip(row, P)))
        if any(not c.is_number for c in row) or not const.is_number:
            return None
        rows.append([sp.nsimplify(c) for c in row] + [sp.nsimplify(const)])
    T = sp.Matrix(rows).col_join(sp.Matrix([[0] * dim + [1]]))
    s0 = sp.Matrix([fold.init[p] for p in fold.params] + [1])
    try:
        state_n = T**N * s0
        state_n1 = (T**(N + 1) * s0)
    except Exception:
        return None
    obs = fold.params.index(fold.observe)
    return sp.expand(state_n1[obs])


def verify_closed_form(fold: Fold, order: int, polys, cf=None):
    """Certificate residual  sum_i p_i(n)*a_{n+i}  with a_n the closed form."""
    a = cf if cf is not None else closed_form(fold)
    if a is None:
        return None                         # path unavailable
    residual = sum(p * a.subs(N, N + i) for i, p in enumerate(polys))
    return sp.simplify(residual) == 0


def _generic_state(fold: Fold, prefix: str):
    """Generic state at index n: affine counters pinned to init + c*n,
    other fields free symbols."""
    counters = _affine_counters(fold)
    return {p: (fold.init[p] + counters[p] * N if p in counters
                else sp.Symbol(f"{prefix}{p}"))
            for p in fold.params}


def verify_generic(fold: Fold, order: int, polys) -> bool:
    """Residual over a generic state (affine counters pinned to init + c*n).
    Exact when the identity holds for all states, not just on-trajectory."""
    P = {p: sp.Symbol(p) for p in fold.params}
    Fmap = {f: sp.expand(fold.updates.get(f, P[f])) for f in fold.params}
    cur = _generic_state(fold, "g_")
    residual = sp.Integer(0)
    for i in range(order + 1):
        # observed value is post-update: a_{n+i} = obs(F(s_{n+i}))
        residual += polys[i] * Fmap[fold.observe].subs(
            {P[f]: cur[f] for f in fold.params})
        cur = {f: sp.expand(Fmap[f].subs({P[g]: cur[g] for g in fold.params}))
               for f in fold.params}
    return sp.simplify(residual) == 0


# --------------------------------------------------------------------- gate

def certify(fold: Fold, window: int = 64):
    """First verified certificate for the observed trajectory.
    Returns (order, polys, method) or (None, reason, saw_candidate)."""
    seq = trajectory(fold, window)
    cf = closed_form(fold)
    saw = False
    for order, polys in candidate_certs(seq):
        saw = True
        if cf is not None:
            if verify_closed_form(fold, order, polys, cf):
                return order, polys, "closed-form"
        elif verify_generic(fold, order, polys):
            return order, polys, "generic-state"
    return None, seq, saw


def _singular_indices(polys, hi: int):
    """Indices k where the leading coefficient p_order(k) = 0 — the step
    k -> k+order is underdetermined there, so those terms must be checked
    explicitly (in addition to the first `order` initial terms)."""
    lead = sp.Poly(polys[-1], N)
    roots = sp.solve(sp.Eq(lead.as_expr(), 0), N)
    return {int(r) for r in roots if r.is_integer and 0 <= int(r) < hi}


def gate(src_a: str, src_b: str, window: int = 64):
    fa = extract_fold(src_a)
    fb = extract_fold(src_b)

    ca = certify(fa, window)
    cb = certify(fb, window)
    seq_a = ca[1] if ca[0] is None else None
    seq_b = cb[1] if cb[0] is None else None
    if seq_a is None:
        seq_a = trajectory(fa, window)
    if seq_b is None:
        seq_b = trajectory(fb, window)

    if len(seq_a) != len(seq_b):
        return "NOT-EQUAL", f"trajectory length {len(seq_a)} vs {len(seq_b)}"
    diff = [a - b for a, b in zip(seq_a, seq_b)]

    if ca[0] is None or cb[0] is None:
        if any(v != 0 for v in diff):
            i = next(i for i, v in enumerate(diff) if v != 0)
            return "NOT-EQUAL", f"diverges at iterate {i}"
        missing = "A" if ca[0] is None else "B"
        return "CANDIDATE", (f"{missing} has no verified certificate "
                             "within bounds; in-window agreement only")
    m_a, m_b = ca[0], cb[0]
    bound = m_a + m_b
    # singular points of either side propagate into the sum-closure
    # recurrence for d: the leading coefficient of the combined operator
    # vanishes wherever either side's does.
    sing = _singular_indices(ca[1], window) | _singular_indices(cb[1], window)
    required = set(range(bound)) | sing
    if max(required, default=0) >= len(diff):
        return "NOT-FOUND-WITHIN-BOUNDS", (
            f"bound {bound} + singular indices {sorted(sing)} exceed "
            f"the {len(diff)}-term window")
    bad = sorted(k for k in required if diff[k] != 0)
    if bad:
        return "NOT-EQUAL", (f"nonzero difference inside the uniqueness "
                             f"bound at iterates {bad}")
    extra = next((i for i, v in enumerate(diff) if v != 0), None)
    if extra is not None:
        return "NOT-EQUAL", f"diverges at iterate {extra} (beyond bound)"
    why = (f"orders {m_a}+{m_b} -> bound {bound}"
           + (f", singular pts {sorted(sing)}" if sing else "")
           + f"; certs [{ca[2]}] {cert_str(*ca[:2])} "
             f"[{cb[2]}] {cert_str(*cb[:2])}")
    return "EQUAL", why


_FIXTURE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "..", "fuzz", "holonomic")

# file -> expected `cert` verdict
_SELFTEST_CERT = [
    ("sq_incr.k", "CERTIFIED"),
    ("sq_direct.k", "CERTIFIED"),
    ("tri.k", "CERTIFIED"),
    ("fact.k", "CERTIFIED"),
    ("tri_builtin.k", "CANDIDATE"),      # non-affine, non-generic-verifiable
    ("refused_fn.k", "REFUSED"),
    ("refused_nofold.k", "REFUSED"),
]

# (a, b) -> expected `equal` verdict
_SELFTEST_EQ = [
    ("sq_incr.k", "sq_direct.k", "EQUAL"),      # sum-of-odds == squares
    ("sq_incr.k", "tri.k", "NOT-EQUAL"),        # diverges inside the bound
    ("fact.k", "fact.k", "EQUAL"),              # identity
]


def _verdict_cert(path):
    try:
        fold = extract_fold(open(path, encoding="utf-8").read())
    except Refused:
        return "REFUSED"
    order, _polys, how = certify(fold)
    if order is None:
        return "CANDIDATE" if how else "NOT-FOUND-WITHIN-BOUNDS"
    return "CERTIFIED"


def _verdict_equal(pa, pb):
    try:
        verdict, _why = gate(open(pa, encoding="utf-8").read(),
                             open(pb, encoding="utf-8").read())
        return verdict
    except Refused:
        return "REFUSED"


def selftest():
    fails = 0
    for f, want in _SELFTEST_CERT:
        got = _verdict_cert(os.path.join(_FIXTURE_DIR, f))
        ok = got == want or (want == "CERTIFIED" and got == "CERTIFIED")
        fails += not ok
        print(f"{'PASS' if ok else 'FAIL'} cert {f}: {got} (want {want})")
    for a, b, want in _SELFTEST_EQ:
        got = _verdict_equal(os.path.join(_FIXTURE_DIR, a),
                             os.path.join(_FIXTURE_DIR, b))
        ok = got == want
        fails += not ok
        print(f"{'PASS' if ok else 'FAIL'} equal {a} {b}: {got} "
              f"(want {want})")
    print(f"{len(_SELFTEST_CERT) + len(_SELFTEST_EQ) - fails} passed, "
          f"{fails} failed")
    return 1 if fails else 0


def main():
    args = sys.argv[1:]
    try:
        if not args:
            print(__doc__)
            return 1
        if args[0] == "selftest":
            return selftest()
        if args[0] == "cert":
            fold = extract_fold(open(args[1], encoding="utf-8").read())
            seq = trajectory(fold, 64)
            head = ", ".join(str(v) for v in seq[:12])
            print(f"observed({fold.observe}): [{head}]"
                  f"{'...' if len(seq) > 12 else ''}")
            cf = closed_form(fold)
            if cf is not None:
                print(f"closed form: a[n] = {sp.sstr(cf)}")
            order, polys, how = certify(fold)
            if order is None:
                print("CANDIDATE" if how else "NOT-FOUND-WITHIN-BOUNDS")
                return 3 if how else 2
            print(f"CERTIFIED ({how}) order={order}: "
                  f"{cert_str(order, polys)}")
            return 0
        if args[0] == "equal":
            a = open(args[1], encoding="utf-8").read()
            b = open(args[2], encoding="utf-8").read()
            verdict, why = gate(a, b)
            print(f"{verdict}  {why}")
            return 0 if verdict == "EQUAL" else 2
        print(__doc__)
        return 1
    except Refused as r:
        print(f"REFUSED: {r}")
        return 4


if __name__ == "__main__":
    sys.exit(main())
