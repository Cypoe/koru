/**
 * Shared corpus-collection helpers.
 *
 * The reference corpus (generate-corpus.js), the teaching tutorial
 * (generate-tutorial.js) and the per-topic skill bundles
 * (generate-skills.js) all walk `tests/regression/` the same way: keep the
 * passing POSITIVE tests, drop the negative MUST_ERROR ones, read the source
 * verbatim. That walk lived in three near-identical copies; this is the one
 * copy they share.
 */

import fs from 'fs';
import path from 'path';

/**
 * The verdict source for "which tests pass?" is the last recorded board —
 * `test-results/latest.json` — never the live SUCCESS markers. Markers are
 * transient run state: a suite run clears and rewrites them per-test as it
 * goes, so generating from them mid-run silently truncated the corpus (and
 * once, on 2026-07-18, collapsed `koru-by-example.md` to one test and deleted
 * ~5000 lines across `docs/by-example/` and `skills/`, looking like a real
 * diff). The snapshot is a record: it only changes when a board completes.
 *
 * Returns a Set of repo-relative test paths — `categorySlug/directory`, e.g.
 * `300_ADVANCED_FEATURES/330_PHANTOM_TYPES/330_005_foo` — one per test whose
 * recorded status is `success`.
 *
 * No snapshot means nothing has recorded a verdict, which means "the set of
 * passing tests" is undefined: throw, don't invent one. A fresh clone is such
 * a boundary — `latest.json` is a tracked symlink to a gitignored dated file,
 * so it dangles until the first `./run_regression.sh` completes.
 */
export function loadPassingPaths(root) {
  const snap = readLatestSnapshot(root);
  if (!snap) {
    throw new Error(
      'cannot derive the corpus: no recorded board at test-results/latest.json.\n' +
        '  The corpus is the set of tests the last full suite run recorded as passing,\n' +
        '  and no run has been recorded. Run ./run_regression.sh once, then regenerate.',
    );
  }
  const passing = new Set();
  for (const cat of snap.categories ?? []) {
    if (!cat.slug || !Array.isArray(cat.tests)) continue;
    for (const t of cat.tests) {
      if (t.status === 'success' && t.directory) {
        passing.add(`${cat.slug}/${t.directory}`);
      }
    }
  }
  return passing;
}

/**
 * Read `test-results/latest.json` and return the parsed board snapshot, or
 * null when none can be read — absent, a dangling symlink (fresh clone), or
 * unparseable. Shared with generate-status.js: every tool that reads the
 * board hits the same pointer materialization on filesystems that cannot
 * represent a symlink.
 */
export function readLatestSnapshot(root) {
  const resultsDir = path.join(root, 'test-results');
  let raw;
  try {
    // A real symlink resolves inside readFileSync; a dangling one throws.
    raw = fs.readFileSync(path.join(resultsDir, 'latest.json'), 'utf8');
  } catch {
    return null;
  }
  try {
    return JSON.parse(raw);
  } catch {
    // A filesystem that cannot represent a symlink materializes latest.json
    // as a plain file holding the link target's name — follow it.
    const pointer = raw.trim();
    if (!/^[0-9A-Za-z._-]+\.json$/.test(pointer)) return null;
    try {
      return JSON.parse(fs.readFileSync(path.join(resultsDir, pointer), 'utf8'));
    } catch {
      return null;
    }
  }
}

/**
 * Walk `dir`, collecting every recorded-passing POSITIVE test (in
 * `passingPaths`, no MUST_ERROR marker). Negative tests "pass" by being
 * rejected — they are examples of what the compiler REJECTS, never
 * what-to-do — so they are excluded from every generated artifact and
 * tracked separately so config references to them can warn specifically
 * instead of silently vanishing.
 *
 * Returns { tests, negativeTests }:
 *   tests        — array of { name, breadcrumbs, dir, input, expected }
 *   negativeTests — Set of basenames of excluded MUST_ERROR tests
 *
 * `breadcrumbs` is the category path above the test (its own dir name dropped),
 * so a test at 300_ADVANCED_FEATURES/330_PHANTOM_TYPES/330_005_foo carries
 * breadcrumbs ["300_ADVANCED_FEATURES", "330_PHANTOM_TYPES"].
 */
export function collectPassing(dir, passingPaths) {
  const negativeTests = new Set();
  const tests = walk(dir, dir, [], negativeTests, passingPaths);
  return { tests, negativeTests };
}

function walk(rootDir, dir, breadcrumbs, negativeTests, passingPaths) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const rel = path.relative(rootDir, dir).split(path.sep).join('/');

  if (passingPaths.has(rel)) {
    // A MUST_ERROR test is negative: it passes by being rejected. Exclude it
    // from the positive example set — every artifact shows what TO do.
    if (entries.some((e) => e.isFile() && e.name === 'MUST_ERROR')) {
      negativeTests.add(path.basename(dir));
      return [];
    }
    // Tests split into the `.k` + host form keep the host bindings (e.g. Zig
    // consts) in input.kz and the portable Koru in input.k. A `.kz` const
    // (`const count: i32 = 42;`) is ZIG text — concat it onto a pure `.k`
    // display and the shown file fails shape-check as pure Koru (KORU114),
    // which is exactly what the frontpage example did before the split. The
    // corpus teaches the PURE Koru surface, so a split test shows input.k
    // alone; a `.kz`-only test (not yet split) falls back to input.kz.
    // Precondition: input.k must be self-contained (its own const block).
    const inputKzPath = path.join(dir, 'input.kz');
    const inputKPath = path.join(dir, 'input.k');
    // The corpus teaches the PURE Koru surface. A `.kz` is Koru embedded in
    // host text, where every Koru line opens with `~` — the host-boundary
    // marker (frag-tilde-marks-the-host-boundary). Pure Koru (`.k`) rejects
    // the tilde outright, so a reference corpus that prints `~tor`, `~import`,
    // `~hello()` would be teaching a spelling the language refuses: the
    // marker is stripped at line start (the only position it occupies in
    // `.kz`) before embedding. Type-declaration bodies, host Zig, and `~`
    // inside strings are untouched — the strip is exactly the marker, nothing
    // else. Applied to both inputs so a `.k` migrating back the other way is
    // represented the same way.
    const deTilde = (s) => s.split('\n').map((l) => l.replace(/^([ \t]*)~/, '$1')).join('\n');
    const parts = [];
    if (fs.existsSync(inputKPath))
      parts.push(deTilde(fs.readFileSync(inputKPath, 'utf-8')).replace(/\n+$/, ''));
    else if (fs.existsSync(inputKzPath))
      parts.push(deTilde(fs.readFileSync(inputKzPath, 'utf-8')).replace(/\n+$/, ''));
    if (parts.length === 0) return [];
    const expectedPath = path.join(dir, 'expected.txt');
    return [
      {
        name: path.basename(dir),
        breadcrumbs: breadcrumbs.slice(0, -1),
        dir,
        input: parts.join('\n\n') + '\n',
        expected: fs.existsSync(expectedPath)
          ? fs.readFileSync(expectedPath, 'utf-8')
          : null,
      },
    ];
  }

  const out = [];
  for (const e of entries) {
    if (e.isDirectory()) {
      out.push(...walk(rootDir, path.join(dir, e.name), [...breadcrumbs, e.name], negativeTests, passingPaths));
    }
  }
  return out;
}

/**
 * Resolve a list of `clusters` (raw breadcrumb paths like
 * "300_ADVANCED_FEATURES" or "300_ADVANCED_FEATURES / 330_PHANTOM_TYPES") to
 * the passing tests living under those subtrees, at any depth. Returns a
 * Map name->test (insertion-ordered) plus the cluster strings that matched
 * nothing, so callers can warn on stale config.
 */
export function resolveClusters(allTests, clusters) {
  const matched = new Map();
  const unknown = [];
  for (const cluster of clusters) {
    const segments = cluster.split(' / ').map((s) => s.trim()).filter(Boolean);
    let count = 0;
    for (const t of allTests) {
      if (t.breadcrumbs.length < segments.length) continue;
      let isMatch = true;
      for (let i = 0; i < segments.length; i++) {
        if (t.breadcrumbs[i] !== segments[i]) { isMatch = false; break; }
      }
      if (isMatch) {
        matched.set(t.name, t);
        count++;
      }
    }
    if (count === 0) unknown.push(cluster);
  }
  return { matched, unknown };
}

/**
 * Demote every markdown heading by one level so pulled prose nests cleanly
 * under a generated H1/H2 structure. H6 is the floor. Lines inside fenced
 * code blocks are skipped so bash comments (`# foo`) aren't clobbered.
 */
export function demoteHeadings(md) {
  const lines = md.split('\n');
  let inFence = false;
  for (let i = 0; i < lines.length; i++) {
    if (/^```/.test(lines[i])) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    lines[i] = lines[i].replace(/^(#{1,5}) /, '$1# ');
  }
  return lines.join('\n');
}

/** Strip numeric prefixes and underscores from a slug for display. */
export function humanize(slug) {
  return slug.replace(/^(\d+_)+/, '').replace(/_/g, ' ');
}

/**
 * Emit one test as a `### name` section: the source verbatim in a ```koru
 * fence, then the expected output (if any) under an **Output:** label.
 */
export function emitTest(t, lines) {
  lines.push(`### ${t.name}`);
  lines.push('');
  lines.push('```koru');
  for (const line of t.input.replace(/\n+$/, '').split('\n')) lines.push(line);
  lines.push('```');
  lines.push('');
  if (t.expected !== null && t.expected.trim() !== '') {
    lines.push('**Output:**');
    lines.push('');
    lines.push('```');
    for (const line of t.expected.replace(/\n+$/, '').split('\n')) lines.push(line);
    lines.push('```');
    lines.push('');
  }
}
