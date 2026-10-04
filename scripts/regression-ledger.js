#!/usr/bin/env node
/**
 * Koru Regression Ledger
 *
 * Regressions are forward motion shedding garbage — the ledger keeps them
 * VISIBLE instead of gating on them. board_delta feeds each full board's
 * diff-snapshots transcript here; every event lands as an append-only row in
 * test-results/regression-ledger.tsv, and the open set (last event per test
 * is `regressed`) reports on stderr for the operator and on stdout as JSON
 * for the float payload.
 *
 * Usage:
 *   node scripts/regression-ledger.js record   < delta-transcript  (board)
 *   node scripts/regression-ledger.js open                          (humans)
 *
 * Ledger row: <iso-date>\t<short-commit>\t<event>\t<test-name>
 * Events are the delta's own vocabulary: `regressed` (success→failure) and
 * `fixed` (failure→success). A test fixed on a later board closes itself —
 * nothing is ever edited or deleted, the log IS the history.
 */

import { readFile, writeFile, access, appendFile } from 'fs/promises';
import { execSync } from 'child_process';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
// KORU_LEDGER_PATH exists so the tool can be exercised without writing fake
// history into the real ledger — boards never set it.
const LEDGER_PATH = process.env.KORU_LEDGER_PATH ||
	join(__dirname, '../test-results/regression-ledger.tsv');

const HEADER = '# date\tcommit\tevent\ttest — append-only regression ledger\n';

async function readLedger() {
	try {
		await access(LEDGER_PATH);
	} catch {
		return [];
	}
	const text = await readFile(LEDGER_PATH, 'utf8');
	return text.split('\n')
		.filter(l => l && !l.startsWith('#'))
		.map(l => {
			const [date, commit, event, test] = l.split('\t');
			return { date, commit, event, test };
		});
}

function openSet(rows) {
	const last = new Map();
	for (const r of rows) last.set(r.test, r);
	return [...last.values()]
		.filter(r => r.event === 'regressed')
		.sort((a, b) => a.test.localeCompare(b.test));
}

function parseDelta(transcript) {
	// Same section-walk the board's failure_verdict does: `  ❌ NAME` under
	// REGRESSIONS is a regression, under NEW TESTS it is a first-run failure
	// (not ledger-worthy — it never was green). `  ✅ NAME` under IMPROVEMENTS
	// is a fix. Other sections hold no regressed/fixed events.
	const events = [];
	let section = '';
	for (const raw of transcript.split('\n')) {
		const l = raw;
		if (l.startsWith('⚠️  REGRESSIONS')) section = 'reg';
		else if (l.startsWith('✅ IMPROVEMENTS')) section = 'imp';
		else if (/^\S/.test(l)) section = '';
		else {
			const m = l.match(/^  (❌|✅) (\S+?)( \(.*)?$/);
			if (!m) continue;
			if (section === 'reg' && m[1] === '❌') events.push({ event: 'regressed', test: m[2] });
			if (section === 'imp' && m[1] === '✅') events.push({ event: 'fixed', test: m[2] });
		}
	}
	return events;
}

async function main() {
	const mode = process.argv[2];

	if (mode === 'open') {
		const rows = await readLedger();
		const open = openSet(rows);
		if (open.length === 0) console.log('🕳 Open regressions: 0');
		for (const r of open) console.log(`  🕳 ${r.test} (since ${r.date.slice(0, 10)}, ${r.commit})`);
		return;
	}

	if (mode !== 'record') {
		console.error('usage: regression-ledger.js record | open');
		process.exit(1);
	}

	const transcript = await new Promise(res => {
		let t = '';
		process.stdin.on('data', d => t += d).on('end', () => res(t));
	});
	const events = parseDelta(transcript);

	try { await access(LEDGER_PATH); }
	catch { await writeFile(LEDGER_PATH, HEADER); }

	if (events.length > 0) {
		const date = new Date().toISOString();
		let commit = 'unknown';
		try { commit = execSync('git rev-parse --short HEAD').toString().trim(); } catch {}
		const lines = events.map(e => `${date}\t${commit}\t${e.event}\t${e.test}`).join('\n') + '\n';
		await appendFile(LEDGER_PATH, lines);
	}

	const open = openSet(await readLedger());
	// stderr: the operator-facing report, printed where board_delta echoes.
	if (open.length === 0) {
		console.error('🕳 Open regressions: 0 — the ledger holds only closed events');
	} else {
		console.error(`🕳 Open regressions: ${open.length} — recorded, not gating`);
		for (const r of open) console.error(`  🕳 ${r.test} (since ${r.date.slice(0, 10)}, ${r.commit})`);
	}
	// stdout: machine-readable for the float payload — this board's own
	// events plus the open set, so consumers don't re-parse the transcript.
	console.log(JSON.stringify({
		regressed: events.filter(e => e.event === 'regressed').map(e => e.test),
		fixed: events.filter(e => e.event === 'fixed').map(e => e.test),
		open: open.length,
		openNames: open.map(r => r.test)
	}));
}

main();
