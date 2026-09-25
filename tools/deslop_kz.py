#!/usr/bin/env python3
"""deslop_kz — clone census for Koru sources over `koruc --ast-canon`.

Sibling of tools/deslop.zig: where that walks the Zig AST's token spans,
this walks the canon JSON the compiler emits per .kz/.k file. The canon
is already trivia-stripped; on top of it we apply the same Type-2
normalization — name and literal payloads fold to markers, structural
fields (dict keys, discriminants, order) stay. Equal normalized hashes
form a clone cluster; a member is shadowed when an ancestor is also
duplicated (the parent being equal IS the bigger clone), matching the
Zig census's maximal-member rule.

Usage:
  deslop_kz.py <koruc> <root>... [--min-nodes=N] [--top=N] [--jobs=N]
"""

import concurrent.futures
import hashlib
import json
import os
import subprocess
import sys

# Fields whose values are names or literal payloads — folded to markers.
# Discriminant fields (kind, variant, booleans, counts) stay literal:
# they are the structure a clone comparison must keep.
NAME_KEYS = {
    "name", "local_name", "binding", "return_binding", "segments",
    "module_qualifier", "module", "pre_label", "content", "value",
    "text", "source_module", "label", "id", "alias", "path",
}

ID, STR = "\x00ID", "\x00STR"


def hash_tree(node, key, memo):
    """Bottom-up pass: (hash, size, label) per node, memoized by object
    identity so the top-down pass can resolve ancestor hashes."""
    i = id(node)
    if i in memo:
        return memo[i]
    if isinstance(node, dict):
        parts, size, label = [], 0, ""
        for k in sorted(node):
            h, s, lab = hash_tree(node[k], k, memo)
            if h is None:
                continue
            parts.append(k + "=" + h)
            size += s
            if not label and lab:
                label = lab
        if not parts:
            memo[i] = (None, 0, "")
            return memo[i]
        tag = next(iter(node)) if len(node) == 1 else ""
        res = (hashlib.blake2b(("{" + ",".join(parts) + "}").encode(),
                              digest_size=16).hexdigest(),
               size, tag or label)
    elif isinstance(node, list):
        parts, size, label = [], 0, ""
        for item in node:
            h, s, lab = hash_tree(item, key, memo)
            if h is None:
                continue
            parts.append(h)
            size += s
            if not label and lab:
                label = lab
        if not parts:
            memo[i] = (None, 0, "")
            return memo[i]
        res = (hashlib.blake2b(("[" + ",".join(parts) + "]").encode(),
                              digest_size=16).hexdigest(),
               size, label)
    else:
        if node is None or node == "":
            memo[i] = (None, 0, "")
            return memo[i]
        if isinstance(node, bool):
            res = (repr(node), 1, "")
        elif isinstance(node, (int, float)):
            res = ("NUM", 1, "")
        else:
            v = (ID if key in NAME_KEYS else
                 STR if "\n" in node or len(node) > 40
                 else json.dumps(node))
            res = (v, 1, node if key in ("name", "local_name", "path")
                   else "")
    memo[i] = res
    return res


def collect(node, memo, file_idx, parents, out):
    """Top-down pass: every node big enough is a member carrying its
    ancestor-hash set for the shadowing rule."""
    h, size, label = memo.get(id(node), (None, 0, ""))
    if h is None:
        return
    if size >= MIN_NODES:
        out.append((h, file_idx, size, label, parents))
    mine = parents | {h}
    if isinstance(node, dict):
        for k in node:
            collect(node[k], memo, file_idx, mine, out)
    elif isinstance(node, list):
        for item in node:
            collect(item, memo, file_idx, mine, out)


def collect_files(roots):
    out = []
    for root in roots:
        if os.path.isfile(root):
            if root.endswith((".kz", ".k")):
                out.append(root)
            continue
        for dirpath, dirs, files in os.walk(root):
            dirs[:] = [d for d in dirs if d not in
                       (".git", ".claude", ".zig-cache", "zig-out",
                        "node_modules")]
            out.extend(os.path.join(dirpath, f) for f in files
                       if f.endswith((".kz", ".k")))
    return sorted(out)


def ast_of(path):
    proc = subprocess.run([KORUC, "--ast-canon", path],
                          capture_output=True, text=True)
    if proc.returncode != 0:
        return None
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    global KORUC, MIN_NODES
    KORUC = os.path.abspath(args[0])
    roots = args[1:]
    MIN_NODES, TOP, JOBS = 32, 20, 8
    for a in sys.argv[1:]:
        if a.startswith("--min-nodes="):
            MIN_NODES = int(a[12:])
        elif a.startswith("--top="):
            TOP = int(a[6:])
        elif a.startswith("--jobs="):
            JOBS = int(a[7:])

    paths = collect_files(roots)
    asts = {}
    with concurrent.futures.ThreadPoolExecutor(JOBS) as ex:
        for path, tree in zip(paths, ex.map(ast_of, paths)):
            if tree is not None:
                asts[path] = tree

    files = sorted(asts)
    members = []
    for fidx, path in enumerate(files):
        memo = {}
        hash_tree(asts[path], None, memo)
        collect(asts[path], memo, fidx, frozenset(), members)

    clusters = {}
    for m in members:
        clusters.setdefault(m[0], []).append(m)
    clustered = {h for h, ms in clusters.items() if len(ms) >= 2}

    # shadowed ⇔ an ancestor's hash is itself clustered (the containing
    # clone is the bigger one; nested copies don't double-count)
    rows, n_clusters, dup_members = [], 0, 0
    for h, ms in clusters.items():
        if len(ms) < 2:
            continue
        n_clusters += 1
        maximal = [m for m in ms if not m[4] & clustered]
        if len(maximal) < 2:
            continue
        dup_members += len(maximal)
        size = maximal[0][2]
        weight = size * (len(maximal) - 1)
        rows.append((weight, size, maximal[0][3], maximal,
                     len({m[1] for m in maximal}) > 1))
    rows.sort(key=lambda r: -r[0])

    skipped = len(paths) - len(asts)
    print(f"files: {len(asts)} parsed, {skipped} skipped   "
          f"nodes hashed >= {MIN_NODES}: {len(members)}")
    print(f"clusters: {n_clusters}   maximal members: {dup_members}\n")
    for i, (w, size, tag, ms, cross) in enumerate(rows[:TOP]):
        print(f"#{i + 1:2} w={w:7.0f}  {len(ms)}x {tag or '?'}  "
              f"{size} leaves{'  [cross-file]' if cross else ''}")
        for m in ms[:8]:
            print(f"      {files[m[1]]}")
        if len(ms) > 8:
            print(f"      ... +{len(ms) - 8} more")


if __name__ == "__main__":
    main()
