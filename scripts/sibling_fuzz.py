#!/usr/bin/env python3
"""Sibling-form differential fuzzer for koru (challenge 007, mechanized).

The oracle is compositionality on surface-form siblings: inline vs multi-line
|> chains must compile identically. Both layouts occur in the corpus, so a
verdict divergence is a real finding, not a syntax invention — the transform
moves whitespace only, on text the corpus already proved parses.

  mutants per input.k:  joined  (fold indented `|>` continuations into head)
                        split   (break inline `|>` chain onto deeper lines)
                        nosplit (head ends with `|>` -> `|>` first on next line)

  verdict: koruc -c  (pass / FRONTEND_COMPILE_ERROR / other-signature)
  extra oracle: koruc --print canonical diff — twins should print
                byte-identical; a diff means layout leaks into the parse tree.

Findings go to .kfuzz/findings/<test>/<mutant>.k — never into tests/ until a
human adjudicates (arbiter call per challenge 007).

Usage:
  python3 scripts/sibling_fuzz.py [--limit N] [--seed S] [--cluster SUBSTR]
                                  [--koruc PATH] [--all]

Only .k files are fuzzed: pure Koru, no embedded host code whose `|`/`>`
sequences could be mangled. Corpus status is read from
test-results/latest.json — the record, not live SUCCESS markers
(see scripts/KNOWN_BUG_corpus_generator_reads_transient_success_markers.md).
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRATCH = os.path.join(ROOT, ".kfuzz")
SNAPSHOT = os.path.join(ROOT, "test-results", "latest.json")
KORUC = os.environ.get("KORUC", os.path.join(ROOT, "zig-out", "bin", "koruc"))

# ---------------------------------------------------------------------------
# layout transforms — whitespace only, corpus-grounded
# ---------------------------------------------------------------------------

def leading_ws(s: str) -> str:
    return s[: len(s) - len(s.lstrip())]


def strip_strings(line: str) -> str:
    """Blank the inside of "..." spans so |> in a string literal is invisible."""
    return re.sub(r'"([^"\\]|\\.)*"', lambda m: '"' + " " * (len(m.group(0)) - 2) + '"', line)


def chain_blocks(lines):
    """Yield (head_idx, [continuation_indices]) for multi-line |> chains.

    A continuation line is deeper-indented than its head and starts with |>.
    """
    i = 0
    while i < len(lines):
        head = lines[i]
        conts = []
        j = i + 1
        while j < len(lines):
            l = lines[j]
            if not l.strip():
                break
            if len(leading_ws(l)) > len(leading_ws(head)) and l.lstrip().startswith("|>"):
                conts.append(j)
                j += 1
            else:
                break
        if conts:
            yield i, conts
            i = j
        else:
            i += 1


def mut_join(src: str) -> str:
    """Fold indented |> continuation lines into the chain head."""
    eol = "\r\n" if "\r\n" in src else "\n"
    lines = src.split(eol)
    consumed = set()
    out = list(lines)
    for head_i, conts in chain_blocks(lines):
        head = lines[head_i]
        tail_parts = [lines[c].lstrip() for c in conts]
        out[head_i] = head.rstrip() + " " + " ".join(p for p in tail_parts)
        consumed.update(conts)
    if not consumed:
        return src
    return eol.join(l for i, l in enumerate(out) if i not in consumed)


def mut_split(src: str) -> str:
    """Break each |> after the first onto its own deeper-indented line."""
    eol = "\r\n" if "\r\n" in src else "\n"
    lines = src.split(eol)
    out = []
    changed = False
    for line in lines:
        s = strip_strings(line)
        # split at |> occurrences after the first — only on "flow" lines
        idxs = [m.start() for m in re.finditer(r"\|>", s)]
        # first |> may be a legit head marker; we split subsequent ones
        if len(idxs) >= 2 and not line.lstrip().startswith("|>"):
            indent = leading_ws(line) + "    "
            out.append(line[: idxs[1]].rstrip())
            for a, b in zip(idxs[1:], idxs[2:] + [len(line)]):
                out.append(indent + line[a:b].rstrip())
            changed = True
        else:
            out.append(line)
    return eol.join(out) if changed else src


def mut_nosplit_head(src: str) -> str:
    """Head ends with `|>` on its own line already — move it to join the next
    token onto the following continuation line's content, i.e. break BEFORE
    the first |> instead of after it."""
    eol = "\r\n" if "\r\n" in src else "\n"
    lines = src.split(eol)
    out = []
    changed = False
    for line in lines:
        s = strip_strings(line)
        m = re.match(r"^(\s*)(.*\S)\s+(\|>)\s+(.*)$", s)
        # `! h |> c` -> `! h\n    |> c`  — only on arm heads (`!`/`|`), the
        # context the corpus proves legal (220_017). A bare step head breaks
        # the "chains onto the step directly above" rule and is just noise.
        if m and s.count("|>") == 1 and line.lstrip()[0:1] in ("!", "|"):
            # groups come from the string-blanked line `s`; slice `line` at
            # the same spans or literal contents are written back as spaces
            indent = m.group(1) + "    "
            out.append(line[m.start(1):m.end(1)] + line[m.start(2):m.end(2)])
            out.append(indent + "|> " + line[m.start(4):m.end(4)])
            changed = True
        else:
            out.append(line)
    return eol.join(out) if changed else src


def mut_comment_insert(src: str) -> str:
    """Insert `//` comment lines between a chain head and its |> continuations.

    Legal-by-diagnostic: the parser's own error message asserts "only comments
    may sit between a step and its continuation" — so a comment there must not
    change the verdict. If it does, the trivia path leaks into semantics.
    """
    eol = "\r\n" if "\r\n" in src else "\n"
    lines = src.split(eol)
    out = []
    changed = False
    # insert a comment before every |> continuation line
    for i, line in enumerate(lines):
        stripped = line.lstrip()
        if stripped.startswith("|>") and i > 0 and lines[i - 1].strip() and not lines[i - 1].lstrip().startswith(("//", "|>")):
            out.append(leading_ws(line) + "// sibling-fuzz trivia")
            changed = True
        out.append(line)
    return eol.join(out) if changed else src


MUTS = {"join": mut_join, "split": mut_split, "headbreak": mut_nosplit_head,
        "comment": mut_comment_insert}

# ---------------------------------------------------------------------------
# driver
# ---------------------------------------------------------------------------

def koruc_check(path: str) -> tuple[bool, str]:
    """(passed, signature). signature = last stderr/stdout line, normalized."""
    try:
        r = subprocess.run(
            [KORUC, "-c", path],
            cwd=ROOT, capture_output=True, text=True, timeout=60,
        )
        ok = r.returncode == 0
        tail = (r.stderr or r.stdout or "").strip().splitlines()
        sig = tail[-1][:200] if tail else ("<clean>" if ok else "<empty>")
        # normalize path + test-name noise out of the signature
        sig = re.sub(re.escape(path), "<f>", sig)
        return ok, sig
    except subprocess.TimeoutExpired:
        return False, "TIMEOUT"


def koruc_print(path: str) -> str | None:
    try:
        r = subprocess.run(
            [KORUC, path, "--print"],
            cwd=ROOT, capture_output=True, text=True, timeout=60,
        )
        return r.stdout if r.returncode == 0 else None
    except subprocess.TimeoutExpired:
        return None


# position/source fields in program.ast.json legitimately differ between
# layout siblings — strip them so the diff measures semantics, not spans
AST_VOLATILE = {"file", "canonical_path", "location", "line", "column", "indent"}


def strip_positions(o):
    if isinstance(o, dict):
        return {k: strip_positions(v) for k, v in o.items() if k not in AST_VOLATILE}
    if isinstance(o, list):
        return [strip_positions(v) for v in o]
    return o


def koruc_emit(path: str) -> str | None:
    """Emit `path` via `koruc -o` and return its real per-program payload —
    program.ast.json, canonicalized with position fields stripped. The `-o`
    .zig itself is a program-independent backend driver skeleton (identical
    for every input), so diffing it is vacuous. None when emit fails.

    NOTE: the module name is derived from the file's basename — twin files
    must share one (emit_text does this) or every pair diffs on it."""
    out = path[:-2] + ".emitted.zig"
    try:
        r = subprocess.run(
            [KORUC, path, "-o", out],
            cwd=ROOT, capture_output=True, text=True, timeout=120,
        )
        # program.ast.json lands beside the INPUT, not beside -o
        astp = os.path.join(os.path.dirname(path), "program.ast.json")
        if r.returncode != 0 or not os.path.exists(astp):
            return None
        try:
            data = json.load(open(astp, encoding="utf-8"))
        finally:
            os.unlink(astp)
        if os.path.exists(out):
            os.unlink(out)
        return json.dumps(strip_positions(data), sort_keys=True)
    except subprocess.TimeoutExpired:
        return None


def emit_text(src: str, slot: str) -> str | None:
    """Emit `src` written as emit/<slot>/prog.k — same basename for both
    twins so the module-name field is identical."""
    d = os.path.join(SCRATCH, "emit", slot)
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, "prog.k")
    with open(p, "w", encoding="utf-8", newline="") as f:
        f.write(src)
    return koruc_emit(p)


def corpus_inputs(cluster_sub=None):
    """All pure-Koru test inputs. The verdict is measured live by `koruc -c`;
    no snapshot dependency (test-results/latest.json is a stale pointer)."""
    out = []
    reg = os.path.join(ROOT, "tests", "regression")
    for dirpath, _dirs, files in os.walk(reg):
        if "input.k" in files:
            rel = os.path.relpath(dirpath, reg)
            if cluster_sub and cluster_sub not in rel:
                continue
            out.append(os.path.join(dirpath, "input.k"))
    return sorted(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=40)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--cluster", default=None, help="substr filter e.g. 670_NESTING")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--print-diff", action="store_true",
                    help="also diff `koruc --print` between orig and mutants")
    ap.add_argument("--emit-diff", action="store_true",
                    help="for pairs where BOTH compile: emit -o zig and diff "
                         "normalized output — catches wrong codegen that -c misses")
    args = ap.parse_args()

    os.makedirs(os.path.join(SCRATCH, "findings"), exist_ok=True)
    tmp = os.path.join(SCRATCH, "mutants")
    os.makedirs(tmp, exist_ok=True)

    inputs = corpus_inputs(args.cluster)
    rng = random.Random(args.seed)
    if not args.all:
        rng.shuffle(inputs)
        inputs = inputs[: args.limit]
    n_mut = n_diff = n_checked = 0
    findings = []

    for inp in inputs:
        name = os.path.basename(os.path.dirname(inp))
        src = open(inp, encoding="utf-8").read()
        if "|>" not in src:
            continue
        n_checked += 1

        rel = os.path.relpath(inp, ROOT)
        o_mut_path = os.path.join(tmp, "__orig.k")
        with open(o_mut_path, "w", encoding="utf-8", newline="") as f:
            f.write(src)
        o_ok, o_sig = koruc_check(o_mut_path)
        o_print = koruc_print(o_mut_path) if args.print_diff else None
        o_emit = emit_text(src, "o") if (args.emit_diff and o_ok) else None

        for mname, fn in MUTS.items():
            mut = fn(src)
            if mut == src:
                continue
            n_mut += 1
            mp = os.path.join(tmp, f"{name}__{mname}.k")
            with open(mp, "w", encoding="utf-8", newline="") as f:
                f.write(mut)
            ok, sig = koruc_check(mp)
            pdiff = None
            if ok and args.print_diff and o_print is not None:
                mprint = koruc_print(mp)
                if mprint is not None and mprint != o_print:
                    pdiff = "\n".join(difflib.unified_diff(
                        o_print.splitlines(), mprint.splitlines(), lineterm=""))[:1500]

            ediff = None
            if ok and o_ok and args.emit_diff and o_emit is not None:
                memit = emit_text(mut, "m")
                if memit is not None and memit != o_emit:
                    ediff = "\n".join(difflib.unified_diff(
                        o_emit.splitlines(), memit.splitlines(), lineterm=""))[:2000]

            if ok != o_ok or pdiff or ediff:
                n_diff += 1
                kind = []
                if ok != o_ok:
                    kind.append(f"verdict: orig={'PASS' if o_ok else 'FAIL'} mut={'PASS' if ok else 'FAIL'}")
                if pdiff:
                    kind.append("print-diff")
                if ediff:
                    kind.append("emit-diff")
                findings.append((name, mname, rel, o_sig, sig, kind, mp))
                print(f"DIVERGENCE {name} [{mname}] {'; '.join(kind)}")
                print(f"   orig sig: {o_sig}\n   mut  sig: {sig}")
                if ediff:
                    print(ediff[:1200])

    print(f"\ndone: inputs={len(inputs)} with-|>={n_checked} mutants={n_mut} divergences={n_diff}")
    if findings:
        fdir = os.path.join(SCRATCH, "findings")
        for name, mname, rel, o_sig, sig, kind, mp in findings:
            dst = os.path.join(fdir, name)
            os.makedirs(dst, exist_ok=True)
            shutil.copy(mp, os.path.join(dst, f"{mname}.k"))
            with open(os.path.join(dst, f"{mname}.note.txt"), "w") as f:
                f.write(f"source: {rel}\nmutant: {mname}\nkind: {'; '.join(kind)}\norig: {o_sig}\nmut : {sig}\n")
        print(f"findings written under {fdir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
