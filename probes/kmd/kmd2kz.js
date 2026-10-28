#!/usr/bin/env node
// kmd2kz — .kmd → .kz lowering spike.
//
// Rules (v0):
//   - A line starting `~` at column 0 (second char not `~`/space) opens a
//     KORU REGION: emitted verbatim until a blank line at brace-depth 0.
//     `|`/other sigils inside are Koru's own problem.
//   - ``` / ~~~ runs (>=3, up to 3 spaces indent) toggle FENCE state; fenced
//     lines are always markdown (this is the one bit of state).
//   - Everything else is MARKDOWN: each line emits `~std/io:print.ln("…")`
//     with `"` and `\` escaped. `{{ … }}` interpolates against `~const`
//     bindings (print.ln strings are already templates). `{% %}` block
//     directives are NOT supported in v0 — `~` constructs are the doc's
//     block logic.
const fs = require('fs');
const [inPath, outPath] = process.argv.slice(2);
let lines = fs.readFileSync(inPath, 'utf8').split('\n');
if (lines.length && lines[lines.length - 1] === '') lines.pop(); // final newline ≠ blank line

const out = [];
let fence = null; // {char, len} inside a fenced block

const fenceMark = (line) => {
    const m = line.match(/^ {0,3}(`{3,}|~{3,})/);
    return m ? { char: m[1][0], len: m[1].length } : null;
};
const isKoruSigil = (line) =>
    line.length > 1 && line[0] === '~' && line[1] !== '~' && line[1] !== ' ';
// verbatim=true (fenced lines): `\x7b\x7b` is invisible to koru's `{{`/`{%`
// scanner (no brace chars at all), decodes to `{{` inside the zig string
// literal, and reads as an escaped literal `{` to std.fmt. `}` likewise.
const emitMd = (line, verbatim = false) => {
    let s = line.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    if (verbatim) s = s.replace(/{/g, '\\x7b\\x7b').replace(/}/g, '\\x7d\\x7d');
    out.push(`~std/io:print.ln("${s}")`);
};

let i = 0;
while (i < lines.length) {
    const line = lines[i];
    if (fence) {
        emitMd(line, true);
        const f = fenceMark(line);
        if (f && f.char === fence.char && f.len >= fence.len) fence = null;
        i++;
        continue;
    }
    const f = fenceMark(line);
    if (f) { fence = f; emitMd(line); i++; continue; }
    if (isKoruSigil(line)) {
        let depth = 0;
        while (i < lines.length) {
            const kl = lines[i];
            if (depth === 0 && kl.trim() === '') break;
            out.push(kl);
            for (const ch of kl) {
                if (ch === '{') depth++;
                else if (ch === '}') depth--;
            }
            i++;
        }
        continue;
    }
    emitMd(line);
    i++;
}
fs.writeFileSync(outPath, out.join('\n') + '\n');
