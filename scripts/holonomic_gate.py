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

Extraction is scoped, not file-global: the transition comes from the
single record arm of the fold's own continue branch (the arm that
re-dispatches `@L`), composed with the re-dispatch args — `@L(s.acc,
s.n)` swaps state and is NOT the same map. `when` is honored as the
loop guard when it sits on that single continue arm (the param_init
shape) and refused everywhere else — a guard we can't see is a stop
condition we'd certify away. Conditional transitions (multiple record
arms) refuse rather than first-match.

Heads are resolved, not assumed: `step = NAME(args)` heads inline the
named tor's if-body — its outcome predicates are conjuncts of the loop
guard and its payloads substitute into record/dispatch exprs (the
`boom f => more {n: f+4}` shape reduces to the autonomous map).
`NAME(args): b |> if(c)` value heads resolve single-return `|zig`
procs — the certificate is then conditioned on that proc body being
the function it states. Unresolvable heads are genuinely forced and
refuse.

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
    guards: list                 # [(lhs, op, rhs)] sympy conjuncts —
                                 # continues while ALL hold
    updates: dict                # field -> sympy expr over state syms
    init: dict                   # field -> int or sympy expr (parametric)
    observe: str                 # field whose trajectory is compared


_ARITH = re.compile(r"^[A-Za-z_@0-9+\-][A-Za-z0-9_@.() \t+\-*/%]*$|^[(]")


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


def _arm_block(src: str, start: int) -> str:
    """A construct line at `start` plus its following `|`-arm lines —
    the extraction scope. Stops at the first non-arm line."""
    lines = src[start:].splitlines()
    keep = [lines[0]]
    for ln in lines[1:]:
        if re.match(r"\s*\|", ln):
            keep.append(ln)
        else:
            break
    return "\n".join(keep)


# alternation ordered long-first so `<=` wins over `<`; written `>|<` to
# keep diff tooling happy
_CMP = r"(\w+)\s*(>=|<=|==|!=|>|<)\s*(-?\w+)"
_COND = r"(.+?)\s*(>=|<=|==|!=|>|<)\s*(.+?)"
_NEG = {">": "<=", "<": ">=", ">=": "<", "<=": ">", "==": "!=", "!=": "=="}


def _parse_cond(text: str, env: dict):
    """`EXPR OP EXPR` -> (lhs, op, rhs) sympy conjunct, or None."""
    m = re.match(r"\s*" + _COND + r"\s*$", text)
    if not m:
        return None
    lhs, op, rhs = m.groups()
    try:
        return (_to_sympy(lhs, env), op, _to_sympy(rhs, env))
    except Refused:
        return None


def _parse_arms(body: str):
    """`| OUT bind? (when c)? => BR (scalar|{rec})` arm lines of a body."""
    arms = []
    for ln in body.splitlines()[1:]:
        am = re.match(r"\s*\|\s*(\w+)(?:\s+(\w+))?\s*"
                      r"(?:when\s+(.*?))?\s*=>\s*(\w+)\s*(.*)$", ln)
        if not am:
            continue
        out, bind, when, br, rest = am.groups()
        rm = re.match(r"\s*{([^}]*)}", rest)
        rec = rm.group(1) if rm else None
        payload = None if rec is not None else (rest.strip() or None)
        arms.append({"out": out, "bind": bind,
                     "when": when.strip() if when else None,
                     "br": br, "rec": rec, "payload": payload})
    return arms


def _rename_params(text: str, hparams, args, params):
    """Rewrite head-param names to their call args. Args must be plain
    state-field names — anything else is refused, not approximated."""
    if len(args) != len(hparams):
        raise Refused(f"head arity {len(args)} != {len(hparams)} params")
    out = text
    for hp, a in zip(hparams, args):
        if not re.fullmatch(r"\w+", a):
            raise Refused(f"head arg not a state field: {a!r}")
        if a not in params:
            raise Refused(f"head arg {a!r} is not a state field")
        out = re.sub(rf"\b{re.escape(hp)}\b", f"({a})", out)
    return out


def _named_head(src, name: str, argstr: str, params, env):
    """Resolve `step = NAME(args)` where NAME is an in-file tor whose body
    is a single `if(cond)` with two `=> OUT payload` arms. Returns
    (preds, payloads): outcome -> guard conjuncts, outcome -> payload
    sympy expr over state symbols. Anything else REFUSED — an
    unresolvable head is a genuinely forced recurrence."""
    pm = re.search(rf"tor\s+{re.escape(name)}\s*{{([^}}]*)}}", src)
    bm = re.search(rf"(?m)^~?{re.escape(name)}\s*=", src)
    if not pm or not bm:
        raise Refused(f"step head {name} not resolvable in-file")
    hparams = [p.split(":")[0].strip()
               for p in pm.group(1).split(",") if p.strip()]
    args = [a.strip() for a in _split_top(argstr) if a.strip()]
    body = _arm_block(src, bm.start())
    gm = re.match(r"\s*\w+\s*=\s*if\(([^)]*)\)", body.splitlines()[0])
    if not gm:
        raise Refused(f"step head {name} is not an if(cond) body")
    cond = _rename_params(gm.group(1), hparams, args, params)
    harms = _parse_arms(body)
    if len(harms) != 2 or harms[0]["when"] or harms[1]["when"]:
        raise Refused(f"step head {name} is not a two-arm if body")
    c = _parse_cond(cond, env)
    if c is None:
        raise Refused(f"head guard not a comparison: {gm.group(1)!r}")
    preds, payloads = {}, {}
    # keyed by produced outcome (a["br"]) — that is what the step's own
    # `| OUT ...` arms dispatch on; the arm label (then/else) only says
    # which side of the head's if produced it
    for a, neg in ((harms[0], False), (harms[1], True)):
        if a["br"] in preds:
            raise Refused(f"step head {name} produces `{a['br']}` under "
                          "both conditions")
        preds[a["br"]] = [(c[0], _NEG[c[1]], c[2])] if neg else [c]
        payloads[a["br"]] = None
        if a["payload"] is not None:
            ptxt = _rename_params(a["payload"], hparams, args, params)
            payloads[a["br"]] = _to_sympy(ptxt, env)
    return preds, payloads


def _value_head(src, name: str, argstr: str, params, env):
    """Resolve `NAME` in `step = NAME(args): b |> if(c)` — a `~proc
    NAME|zig { return <expr>; }` single-return proc. The certificate
    is conditioned on the proc body literally returning <expr>."""
    pm = re.search(rf"~?proc\s+{re.escape(name)}\s*\|zig\s*{{(.*?)}}",
                   src, re.S)
    if not pm:
        raise Refused(f"value head {name} is not a resolvable |zig proc")
    pbody = pm.group(1)
    # a truncated or multi-return proc is not a single function — the
    # certificate would condition on a body that never ran
    if pbody.count("{") != pbody.count("}") or pbody.count("return") != 1:
        raise Refused(f"value head {name}: proc body is not a single "
                      "`return e;`")
    rm = re.search(r"return\s+(.+?)\s*;", pbody)
    if not rm:
        raise Refused(f"value head {name}: proc body is not `return e;`")
    tm = re.search(rf"tor\s+{re.escape(name)}\s*{{([^}}]*)}}", src)
    hparams = [p.split(":")[0].strip()
               for p in tm.group(1).split(",") if p.strip()] if tm else []
    args = [a.strip() for a in _split_top(argstr) if a.strip()]
    return _to_sympy(_rename_params(rm.group(1), hparams, args, params),
                     env)


def extract_fold(src: str, label: str = "") -> Fold:
    src = "\n".join(ln.split("//")[0] for ln in src.splitlines())

    m = re.search(r"#(\w+)\s+(\w+)\(([^)]*)\)", src)
    if not m:
        raise Refused("no #L step(...) fold found")
    lab, step_name, init_args = m.groups()
    if label and label != lab:
        raise Refused(f"fold #{label} not found (found #{lab})")

    pm = re.search(rf"tor\s+{re.escape(step_name)}\s*{{([^}}]*)}}", src)
    if not pm:
        raise Refused(f"step tor {step_name} decl not found")
    params = [p.split(":")[0].strip() for p in pm.group(1).split(",") if p.strip()]
    env = {p: sp.Symbol(p) for p in params}

    # fold-call arm block: the `| <br> s |> @L(...)` arm names the
    # continue branch and how its payload re-enters the step
    call_block = _arm_block(src, m.start())
    if re.search(r"\bwhen\b", call_block):
        raise Refused("`when` on a fold continuation arm — loop-edge "
                      "condition not modeled")
    disp = re.findall(rf"\|\s*(\w+)\s+(\w+)\s*\|>\s*@{re.escape(lab)}"
                      r"\(([^)]*)\)", call_block)
    if len(disp) > 1:
        raise Refused("multiple @L re-dispatch arms — the continue branch "
                      "is chosen per-outcome, not one autonomous transition")
    if not disp:
        raise Refused(f"no `| <br> s |> @{lab}(...)` re-dispatch arm")
    cont_branch, bind, argstr = disp[0]

    # step body scope: `step_name = <head>` plus its `|` arms only —
    # file-global searches could pick a different tor's record
    bm = re.search(rf"(?m)^~?{re.escape(step_name)}\s*=", src)
    if not bm:
        raise Refused(f"step tor {step_name} body not found")
    body = _arm_block(src, bm.start())
    head = body.splitlines()[0].split("=", 1)[1].strip()
    arms = _parse_arms(body)

    # head resolution -> outcome preds / payloads / extra bindings
    # preds[outcome] = conjuncts that must hold for the head to produce
    # that outcome; payloads[outcome] = its scalar payload expr (or None)
    extra_env = dict(env)          # arm-visible names beyond state fields
    preds, payloads = {}, {}
    hm = re.match(r"if\(([^)]*)\)$", head)
    nm = re.match(r"(\w+)\(([^)]*)\)$", head)
    vm = re.match(r"(\w+)\(([^)]*)\)\s*:\s*(\w+)\s*\|>\s*if\(([^)]*)\)$",
                  head)
    if hm:
        c = _parse_cond(hm.group(1), env)
        if c is None:
            raise Refused(f"guard is not a single comparison: "
                          f"{hm.group(1)!r}")
        preds = {"then": [c], "else": [(c[0], _NEG[c[1]], c[2])]}
    elif vm:
        hname, hargs, vbind, vcond = vm.groups()
        ret = _value_head(src, hname, hargs, params, env)
        extra_env[vbind] = ret
        venv = dict(extra_env)
        c = _parse_cond(vcond, venv)
        if c is None:
            raise Refused(f"value-head guard not a comparison: {vcond!r}")
        preds = {"then": [c], "else": [(c[0], _NEG[c[1]], c[2])]}
    elif nm:
        preds, payloads = _named_head(src, nm.group(1), nm.group(2),
                                      params, env)
    else:
        raise Refused(f"step head not extractable: {head!r}")

    # continue arm = the single arm producing `cont_branch` as a record;
    # its outcome's pred conjuncts + its `when` ARE the loop guard.
    cont_arms = [a for a in arms if a["br"] == cont_branch]
    stray_when = any(a["when"] for a in arms if a["br"] != cont_branch)
    if stray_when:
        raise Refused("`when` on a non-continue arm — the stop/selection "
                      "condition is not modeled")
    if len(cont_arms) > 1:
        raise Refused(f"multiple `=> {cont_branch} {{...}}` arms — a "
                      "conditional transition, not one autonomous map")
    if not cont_arms:
        raise Refused("no {f: e, ...} update record on the continue arm")
    ca = cont_arms[0]
    if ca["rec"] is None:
        raise Refused("continue arm produces no {f: e, ...} record")
    if ca["out"] not in preds:
        raise Refused(f"continue outcome `{ca['out']}` not produced by "
                      "the resolved head")
    guards = list(preds[ca["out"]])
    if ca["when"] is not None:
        wc = _parse_cond(ca["when"], extra_env)
        if wc is None:
            raise Refused(f"continue `when` is not a comparison: "
                          f"{ca['when']!r}")
        guards.append(wc)
    if ca["bind"] and ca["bind"] != "_":
        pl = payloads.get(ca["out"])
        if pl is None:
            raise Refused(f"continue binds `{ca['bind']}` but outcome "
                          f"`{ca['out']}` carries no scalar payload")
        extra_env[ca["bind"]] = pl

    raw_updates = {}
    for kv in _split_top(ca["rec"]):
        if ":" in kv:
            f, e = kv.split(":", 1)
            raw_updates[f.strip()] = e.strip()

    # init args from `#L step(n: start, acc: 0)` — positional args map to
    # fields in declaration order (`#L tick(limit, passes: 0)`); free
    # names resolved via the concrete call site `entry(param: lit)` found
    # anywhere in the file
    positional = []
    named = {}
    for a in init_args.split(","):
        a = a.strip()
        if ":" in a:
            k, v = a.split(":", 1)
            named[k.strip()] = v.strip()
        elif a:
            positional.append(a)
    for i, v in enumerate(positional):
        if i < len(params):
            named.setdefault(params[i], v)
    callers = dict(re.findall(r"(\w+)\s*:\s*(-?\d+)", src))
    init = {}
    for p in params:
        v = named.get(p, "")
        if re.fullmatch(r"-?\d+", v or ""):
            init[p] = int(v)
        elif v in callers:
            init[p] = int(callers[v])
        elif not v:
            raise Refused(f"missing init for field {p}")
        else:
            # parametric init: a free name or arithmetic expression over
            # caller-supplied parameters — kept symbolic; certificates are
            # fitted on a specialization and verified for all values
            env0 = {nm: sp.Symbol(nm)
                    for nm in re.findall(r"[A-Za-z_]\w*", v)}
            init[p] = _to_sympy(v, env0)

    updates = {f: _to_sympy(e, extra_env) for f, e in raw_updates.items()}
    fmap = {f: updates.get(f, env[f]) for f in params}

    # `| more s |> @L(a1, ...)` re-dispatch args compose over the record
    # state: next field_i = a_i[s.f := F_f(state)]. Identity when args are
    # `s.<field>` in declaration order; swaps, resets, and arithmetic all
    # change the transition — ignoring them would certify the wrong map.
    args = [a.strip() for a in _split_top(argstr) if a.strip()]
    if len(args) != len(params):
        raise Refused(f"@{lab} re-dispatch arity {len(args)} != "
                      f"{len(params)} params")
    updates = {}
    for i, a in enumerate(args):
        if ":" in a:
            a = a.split(":", 1)[1].strip()
        a = re.sub(rf"\b{re.escape(bind)}\.(\w+)", r"(\1)", a)
        # simultaneous: the update exprs are evaluated on the CURRENT
        # state — without it, subs would re-substitute field names inside
        # F itself (acc -> acc+2n-1, then n -> n+1 inside that: wrong)
        updates[params[i]] = sp.expand(
            _to_sympy(a, extra_env).subs(fmap, simultaneous=True))

    dm = re.search(r"=>\s*done\s+(\w+)", body)
    obs = dm.group(1) if dm and dm.group(1) in params else params[-1]

    return Fold(step_name, params, guards, updates, init, obs)


# ------------------------------------------------------------- trajectory

_OPS = {"<": lambda a, b: a < b, ">": lambda a, b: a > b,
        "<=": lambda a, b: a <= b, ">=": lambda a, b: a >= b,
        "==": lambda a, b: a == b, "!=": lambda a, b: a != b}


def trajectory(fold: Fold, steps: int, bounded: bool = True):
    """Iterate the transition numerically: observed post-update values.
    bounded=True stops at the guard (the program's actual output);
    bounded=False iterates F regardless — the certificate is a property
    of the transition, not of where the program chooses to stop."""
    state = dict(fold.init)
    out = []
    for _ in range(steps):
        if bounded and fold.guards:
            stop = False
            for lhs, op, rhs in fold.guards:
                try:
                    # `not <relational>` bool()s it — a symbolic lhs/rhs
                    # raises TypeError, the undecidable signal
                    if not _OPS[op](lhs.subs(state), rhs.subs(state)):
                        stop = True
                        break
                except TypeError:
                    raise Refused(
                        "guard undecidable under parametric init")
            if stop:
                break
        nxt = {}
        for f in fold.params:
            e = fold.updates.get(f, sp.Symbol(f))
            v = e.subs(state)
            if v.is_number:
                nxt[f] = sp.Integer(v) if v.is_Integer else v
            else:
                nxt[f] = sp.expand(v)   # parametric init: symbolic iterate
        out.append(nxt[fold.observe])
        if any(v.is_number and abs(v) > sp.Integer(10)**200
               for v in nxt.values()):
            raise Refused("trajectory magnitude exceeds 10^200 — "
                          "super-exponential growth outside the fragment")
        state = nxt
    return out


def init_symbols(fold: Fold):
    """Free symbols in the initial state — caller-supplied parameters."""
    out = set()
    for v in fold.init.values():
        if isinstance(v, sp.Basic):
            out |= v.free_symbols
    return sorted(out, key=str)


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
        state_n1 = (T**(N + 1) * s0).as_explicit()
    except Exception:
        return None                    # symbolic power failed (e.g. nilpotent)
    if not isinstance(state_n1, sp.MatrixBase):
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


def _guard_key(g):
    """Canonical integer-domain form of a conjunct: a > b  is  a-b-1 >= 0
    over Z, so `x > 0` and `x >= 1` share a key. Sets of keys are what the
    parametric guard-compare measures."""
    lhs, op, rhs = g
    d = sp.expand(lhs - rhs)
    if op == ">":
        return (str(sp.expand(d - 1)), ">=")
    if op == ">=":
        return (str(d), ">=")
    if op == "<":
        return (str(sp.expand(-d - 1)), ">=")
    if op == "<=":
        return (str(sp.expand(-d)), ">=")
    return (str(d), op)                      # == and !=


def _specialize(fold: Fold, spec):
    init = {f: (v.subs(spec) if isinstance(v, sp.Basic) else v)
            for f, v in fold.init.items()}
    return Fold(fold.step_name, fold.params, fold.guards, fold.updates,
                init, fold.observe)


def _init_specs(fa: Fold, fb: Fold):
    """Sampled init values for guard-witness search under parametric
    init — a spread around typical guard thresholds, same value to all
    symbols (a line, not a grid: good enough for witnesses)."""
    syms = sorted(set(init_symbols(fa)) | set(init_symbols(fb)), key=str)
    for v in (-20, -13, -9, -5, -2, -1, 0, 1, 2, 3, 5, 7, 11):
        yield {s: v for s in syms}


# --------------------------------------------------------------------- gate

def certify(fold: Fold, window: int = 64):
    """First verified certificate for the observed trajectory.
    Returns (order, polys, method) or (None, reason, saw_candidate).

    Under parametric init the trajectory is symbolic: the certificate is
    fitted on a numeric specialization (distinct small primes — generic
    enough to avoid accidental degeneracy) and then verified on the
    symbolic closed form / generic state, so the verified cert holds for
    all parameter values, not just the specialization."""
    seq = trajectory(fold, window, bounded=False)
    cf = closed_form(fold)
    syms = set()
    for v in seq:
        if isinstance(v, sp.Basic):
            syms |= v.free_symbols
    seq_fit = seq
    if syms:
        spec = {s: p for s, p in
                zip(sorted(syms, key=str), (3, 5, 7, 11, 13, 17))}
        seq_fit = [v.subs(spec) for v in seq]
    saw = False
    for order, polys in candidate_certs(seq_fit):
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

    # cheap refutation first: output length, then any nonzero iterate in
    # the window is a concrete witness — no certificates needed. The
    # length check needs a decidable guard; under parametric init the
    # guard is symbolic, so it is skipped (length is param-dependent
    # anyway and a symbolic divergence witness below is still honest:
    # a nonzero expression in the params means the folds differ as
    # functions of their inputs).
    try:
        out_a = trajectory(fa, window, bounded=True)
        out_b = trajectory(fb, window, bounded=True)
        if len(out_a) != len(out_b):
            return "NOT-EQUAL", (f"output length {len(out_a)} vs "
                                 f"{len(out_b)}")
    except Refused:
        if not (init_symbols(fa) or init_symbols(fb)):
            raise
        # bounded length is param-dependent — but the stop conditions
        # are still comparable. Identical F under different guards means
        # the programs differ as functions of their inputs; witness it
        # on a sampled init or refuse the comparison honestly.
        if {_guard_key(g) for g in fa.guards} != \
           {_guard_key(g) for g in fb.guards}:
            for spec in _init_specs(fa, fb):
                try:
                    la = len(trajectory(_specialize(fa, spec), window))
                    lb = len(trajectory(_specialize(fb, spec), window))
                except Refused:
                    continue
                if la != lb:
                    return ("NOT-EQUAL",
                            f"output length {la} vs {lb} at init {spec}")
            return ("CANDIDATE",
                    "stop conditions differ but agree on sampled inits")
    seq_a = trajectory(fa, window, bounded=False)
    seq_b = trajectory(fb, window, bounded=False)
    diff = [a - b for a, b in zip(seq_a, seq_b)]
    bad = next((i for i, v in enumerate(diff) if sp.simplify(v) != 0),
               None)
    if bad is not None:
        return "NOT-EQUAL", f"diverges at iterate {bad}"

    ca = certify(fa, window)
    cb = certify(fb, window)
    if ca[0] is None or cb[0] is None:
        missing = "A" if ca[0] is None else "B"
        return "CANDIDATE", (f"{missing} has no verified certificate "
                             "within bounds; in-window agreement only")
    m_a, m_b = ca[0], cb[0]
    bound = m_a + m_b
    # singular points of either side propagate into the sum-closure
    # recurrence for d: the leading coefficient of the combined operator
    # vanishes wherever either side's does.
    sing = (_singular_indices(ca[1], window)
            | _singular_indices(cb[1], window))
    required = set(range(bound)) | sing
    if max(required, default=0) >= len(diff):
        return "NOT-FOUND-WITHIN-BOUNDS", (
            f"bound {bound} + singular indices {sorted(sing)} exceed "
            f"the {len(diff)}-term window")
    # diff is all-zero on the window here; required terms check out by
    # construction — the certificate bound is what turns window-agreement
    # into identical-everywhere
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
    ("sum_desc.k", "CERTIFIED"),         # 020_028 corpus fold, 5-iter output
    # 320_152 corpus fold — `n` init is a caller-supplied parameter, the
    # certificate is fitted on a specialization and verified ∀ values
    ("param_init.k", "CERTIFIED"),
    ("refused_fn.k", "REFUSED"),
    ("refused_nofold.k", "REFUSED"),
    # conditional transition — two `=> more {…}` records under different
    # `when` guards; first-match extraction used to certify one of them
    ("when_mutant.k", "REFUSED"),
    # `when` on a non-continue arm — the stop/selection condition is
    # invisible to the model
    ("when_exit.k", "REFUSED"),
    # swapped @L re-dispatch args — the record is identical to sq_incr's
    # but the composed transition is not; certifies its own dynamics
    ("swap_dispatch.k", "CERTIFIED"),
    # arm-payload shape (320_151): `| boom f => more {n: f+4}` — f is
    # resolved through the head (worker booms n under n<0) to n+4;
    # the guard gains the head-outcome conjunct n<0 alongside left>0
    ("payload_retry.k", "CERTIFIED"),
    # head-bound shape (320_097): `clock(passes): n` — the |zig proc's
    # single `return passes;` binds n := passes; F is passes+1 under
    # passes < limit (cert conditioned on the proc body)
    ("value_head.k", "CERTIFIED"),
]

# (a, b) -> expected `equal` verdict
_SELFTEST_EQ = [
    ("sq_incr.k", "sq_direct.k", "EQUAL"),      # sum-of-odds == squares
    ("sq_incr.k", "tri.k", "NOT-EQUAL"),        # diverges inside the bound
    ("fact.k", "fact.k", "EQUAL"),              # identity
    # 020_028 corpus fold vs its commuted twin — GA-style mutation
    # proven identical; bound 2 + singular point at n=10 is checked
    ("sum_desc.k", "sum_desc_commuted.k", "EQUAL"),
    # 320_152 corpus fold vs commuted updates — certified identical for
    # ALL values of the parametric init `n` (singular point at n=2)
    ("param_init.k", "param_init_commuted.k", "EQUAL"),
    # @L args swapped — same record, different transition; caught by the
    # composed map (bounded lengths 19 vs 5), was EQUAL pre-fix
    ("sq_incr.k", "swap_dispatch.k", "NOT-EQUAL"),
    # `when` guard tightened left>0 -> left>1 — same F, one fewer real
    # iterate; the bounded length check (3 vs 2) is what makes the
    # certificate claim about the program, not just the transition
    ("param_init.k", "when_shorter.k", "NOT-EQUAL"),
    # arm-payload spelling vs inlined spelling — `n: f+4` with f the
    # boom payload resolves to the same transition AND the same guard
    # set; certified identical as functions of the parametric init
    ("payload_retry.k", "param_init.k", "EQUAL"),
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
            try:
                seq = trajectory(fold, 64)
                tag = ""
            except Refused:
                # symbolic guard conjunct — the program's output length
                # is param-dependent; show the transition iterates
                seq = trajectory(fold, 64, bounded=False)
                tag = " (unbounded: guard is param-dependent)"
            head = ", ".join(str(v) for v in seq[:12])
            print(f"observed({fold.observe}): [{head}]"
                  f"{'...' if len(seq) > 12 else ''}{tag}")
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
