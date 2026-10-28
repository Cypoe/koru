# `.kmd` — Markdown as a host language (ruling 2026-10-25)

Decision: **`.kmd` joins the `.k<host>` file extension family**
(`file_types.zig`: `.kz` zig, `.kjs` js, `.kcs` cs, `.kc` c, `.kgpu` gpu)
as the file whose hostlines are **Markdown** (`hostLangOfFile → "md"`).
It is the first host whose bytes are *data, not code*: instead of landing
at code position in an emitted program, an md hostline is document text.

## The file is a comptime program; the document is its residue

A `.kmd` file is implicitly a `~[comptime]` module — the annotation is
stamped by the parser, not written by the author (module-level
`[comptime]` already means "all items in this module are comptime by
default"; `[runtime]` remains the per-item escape). Compile-time
evaluation consumes every `~` construct; what remains — md hostlines plus
string-valued comptime results, in file order — is emitted as the `.md`
artifact.

**Residue contract:** anything left after comptime consumption that is
not document text is a compile failure, not silent output. Same wall
shape as `KORU141` (a construct the comptime pipeline cannot consume is
refused, never muted).

## File grammar

- `~` at **column 0** (second char not `~`, space, or tab) opens a Koru
  construct; the construct consumes its own extent exactly as in `.kz`.
- A fenced code block (``` or `~~~`, run ≥3, ≤3 spaces indent) makes
  every line inside it document text — the one bit of parser state.
- Everything else is a document line, including blank lines, tables
  (`|`-led lines are prose at top level — `|`/`!` are only structural
  inside a construct extent), `~~strikethrough`, and indented code
  (column-0 sigil rule makes `    ~x` text automatically).
- `{{ }}` / `{% %}` in document lines render through the Liquid engine
  against the comptime environment at emission time. Fenced code samples
  stay literal — a ` ```koru ```` block's `~` lines are displayed, not
  executed. (Whether fenced ` ```koru ```` samples are *also* compiled as
  a drift wall is a separate, later ruling.)

## Non-goals for v1

- **Collections / multi-page output.** The contract is written plural —
  residue is *named artifacts* — but v1 emits one `.md`. Iterating a data
  set into pages is gated on comptime-eval rungs (loop-walking, data
  ingress), not on this design.
- **Runtime doc generation.** The earlier spike (doc-as-program, stdout
  is the document, `print.ln` per line — `probes/kmd/`) proved the file
  grammar works end to end and is retained as evidence, but the
  stdout-hoist is not the model: there is no runtime artifact here.
- **Per-declaration doc rendering** (`~[template]` per-decl one-shot
  mode) — removed by `TEMPLATE_SPELLING.md`, stays removed.

## Where the work lives

1. `file_types.zig` — extension + host tag (one line + tests).
2. `parser.zig` — `is_kmd` mode: fence state, column-0 sigil, blank
   lines and `|`/`!` as document lines; implicit `comptime` in
   `module_annotations`.
3. Emission — md residue assembly in file order + the residue-refusal
   wall + the `.md` artifact write (`emit_package_files.zig` is the
   precedent for a non-zig artifact out of the backend).
4. Interpolation — `liquid.zig` render of document lines against the
   comptime env.

Open question flagged at design time: **ordering** — whether the
comptime-consumption path is position-preserving enough to splice
evaluated string results between the prose lines that surround them.
To be measured when the emission stage lands.
