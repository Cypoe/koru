#!/usr/bin/env node
'use strict';
// The files that determine a test's backend binary — its LINKED CLOSURE.
//
// Usage: backend_closure.js <build-file>
//
// Prints "<path relative to the repo root> <sha256>" per line, sorted, for every
// file the backend links, EXCEPT the test's own generated inputs (backend.zig,
// the build file, backend_output_emitted.zig) — the caller hashes those itself,
// with its own rules.
//
// Why a closure and not the source directory: the key must be COMPLETE (every
// file the binary embeds; an omission serves a stale backend) and MINIMAL
// (nothing else; an inclusion re-mints every cached backend for an edit that
// cannot change one). A directory-wide salt hashed 269 files where a backend
// links 51, so editing src/main.zig — 8k lines of CLI the backend never links —
// or a koru_std/*.kz module threw away every cached backend on the machine.
//
// The build file is the authority for module IDENTITIES (`@import("backend_output")`
// names a module rooted at backend_output_emitted.zig, so a filename guess
// misses it). Relative `@import("x.zig")` never appears there — Zig resolves it
// against the importing file's directory, and 12 files in src/ are reachable
// only that way — so the graph is walked.
//
// Exits nonzero, printing nothing to stdout, when the closure cannot be proven:
// an unresolvable import, or an `@import` whose argument is not a literal string
// (invisible to any static walk). The caller must then key nothing at all and
// let the test rebuild.
//
// Lives in node because the harness already requires node, and because lexing
// Zig needs string/char/comment state: the first cut of this walk did it in awk
// and measured 5.5s per test against ~60ms here.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const EXTERNAL = new Set(['std', 'builtin', 'root']);

function die(msg) {
    process.stderr.write(`backend_closure: ${msg}\n`);
    process.exit(1);
}

function lineOf(src, idx) {
    let line = 1;
    for (let i = 0; i < idx; i++) if (src[i] === '\n') line++;
    return line;
}

// Every `@import("<literal>")` in a file, from its CODE only. This repo emits
// Zig as text, so a naive scan finds imports that are not there:
//   src/visitor_emitter.zig:4812  if (std.mem.startsWith(u8, rhs, "@import("))
// ends a string literal with `(`, and src/codegen_utils.zig:578 names
// `@import("vaxis")` in a comment (vaxis is not even a dependency here).
function importsOf(file) {
    const src = fs.readFileSync(file, 'utf8');
    const out = [];
    const n = src.length;
    let i = 0;
    while (i < n) {
        const c = src[i];
        if (c === '/' && src[i + 1] === '/') {                 // line comment
            const j = src.indexOf('\n', i);
            i = j < 0 ? n : j;
            continue;
        }
        if (c === '"' || c === "'") {                          // string / char literal
            const quote = c;
            i++;
            while (i < n) {
                if (src[i] === '\\') { i += 2; continue; }
                if (src[i] === quote) { i++; break; }
                i++;
            }
            continue;
        }
        if (c === '\\' && src[i + 1] === '\\') {               // multiline-string text
            const j = src.indexOf('\n', i);
            i = j < 0 ? n : j;
            continue;
        }
        if (src.startsWith('@import(', i)) {
            let j = i + '@import('.length;
            while (src[j] === ' ' || src[j] === '\t') j++;
            if (src[j] !== '"') {
                die(`non-literal @import in ${file}:${lineOf(src, i)} — closure unprovable`);
            }
            let k = j + 1;
            let name = '';
            while (k < n) {
                if (src[k] === '\\') { name += src[k + 1] || ''; k += 2; continue; }
                if (src[k] === '"') break;
                name += src[k];
                k++;
            }
            out.push(name);
            i = k + 1;
            continue;
        }
        i++;
    }
    return out;
}

// `const REL_TO_ROOT = "..."` and every `const <sym>_module = b.createModule(.{`
// with a `root_source_file`, plus every `<x>.addImport("<name>", <sym>)` edge.
function buildGraph(buildFile, testDir) {
    const text = fs.readFileSync(buildFile, 'utf8');
    const repoMatch = /const\s+REL_TO_ROOT\s*=\s*"([^"]*)"/.exec(text);
    const repoRoot = repoMatch ? repoMatch[1] : path.dirname(path.dirname(__dirname));

    const roots = new Map();     // symbol -> resolved path
    const names = new Map();     // import name -> resolved path
    const blockRe = /const\s+([A-Za-z0-9_]+_module)\s*=\s*b\.createModule\(\.\{([\s\S]*?)\n\s*\}\);/g;
    let m;
    while ((m = blockRe.exec(text)) !== null) {
        const sym = m[1];
        const src = /root_source_file\s*=\s*(.*)/.exec(m[2]);
        if (!src) continue;
        const quoted = /"([^"]*\.zig)"/.exec(src[1]);
        if (!quoted) continue;
        const resolved = resolveRaw(quoted[1], testDir, repoRoot);
        if (resolved) roots.set(sym, resolved);
    }
    const edgeRe = /([A-Za-z0-9_]+)\.addImport\("([^"]+)",\s*([A-Za-z0-9_]+)\)/g;
    while ((m = edgeRe.exec(text)) !== null) {
        if (roots.has(m[3])) names.set(m[2], roots.get(m[3]));
    }
    return { repoRoot, roots, names };
}

// A build-file path may be `REL_TO_ROOT ++ "/src/x.zig"` (repo-relative with a
// leading slash), `b.path("x.zig")` (test-relative), or an absolute path.
function resolveRaw(raw, testDir, repoRoot) {
    for (const cand of [raw, path.join(testDir, raw), path.join(repoRoot, raw)]) {
        if (fs.existsSync(cand) && fs.statSync(cand).isFile()) return path.resolve(cand);
    }
    return null;
}

function main() {
    const buildArg = process.argv[2];
    if (!buildArg) die('usage: backend_closure.js <build-file>');
    const buildFile = path.resolve(buildArg);
    if (!fs.existsSync(buildFile)) die(`no build file at ${buildFile}`);
    const testDir = path.dirname(buildFile);

    const { repoRoot, roots, names } = buildGraph(buildFile, testDir);
    const self = new Set([
        path.join(testDir, 'backend.zig'),
        buildFile,
        path.join(testDir, 'backend_output_emitted.zig'),
    ]);

    const seen = new Set();
    let frontier = [];
    const push = (p) => {
        if (!p || seen.has(p)) return;
        seen.add(p);
        frontier.push(p);
    };
    for (const p of roots.values()) push(p);
    push(path.join(testDir, 'backend.zig'));
    push(path.join(testDir, 'backend_output_emitted.zig'));
    if (seen.size === 0) die('empty closure');

    while (frontier.length > 0) {
        const discovered = [];
        for (const file of frontier) {
            for (const name of importsOf(file)) {
                if (EXTERNAL.has(name)) continue;
                let target = null;
                if (name.endsWith('.zig')) {
                    target = resolveRaw(path.join(path.dirname(file), path.basename(name)), testDir, repoRoot);
                } else if (names.has(name)) {
                    target = names.get(name);
                } else {
                    target = resolveRaw(name + '.zig', testDir, repoRoot)
                        || [path.join(repoRoot, 'src', name + '.zig'),
                            path.join(repoRoot, 'koru_std', name + '.zig'),
                            path.join(testDir, name + '.zig')].find((c) => fs.existsSync(c)) || null;
                }
                if (!target) die(`cannot resolve @import("${name}") in ${file}`);
                if (!seen.has(target)) { seen.add(target); discovered.push(target); }
            }
        }
        frontier = discovered;
    }

    const lines = [];
    for (const file of [...seen].sort()) {
        if (self.has(file)) continue;
        const digest = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
        let rel = path.relative(repoRoot, file);
        if (rel.startsWith('..')) rel = file;                  // outside the repo: keep it absolute
        lines.push(`${rel} ${digest}`);
    }
    if (lines.length === 0) die('empty closure listing');
    lines.sort();
    process.stdout.write(lines.join('\n') + '\n');
}

main();
