# Koru friction catalog — session devin (effect-branch relay probe, /tmp/relaytest + /tmp/collision)

Devin-CLI session; journals not wired into sessions.db — captured by hand.
3 diagnostics across 2 erroring compiles; 1 module-model confusion that
presented as a misfiled diagnostic; 1 latency finding (500x).

## Diagnostics

| # | code | file:line | diagnostic | offending source | what followed |
|---|---|---|---|---|---|
| 1 | PARSE003 | input.kz:12 | single continuation branch 'done' carrying a payload is a one-variant tag union — declare the single output as a bare return instead: `-> i64` | `~tor emit-done { v: i64 }`<br>`\| done i64` | Teach-hit — guessed `\| done i64` for a single-output helper, message named the exact fix (`-> i64`). The model it hides ("a lone payload arm IS a bare return") only arrives via refusal. |
| 2 | PARSE005 | input.kz:17 | redundant explicit label 'v:' — the value 'v' already puns to 'v' — drop the label | `\| halved v \|> on-halved(v: v)` | Teach-hit — `x: x` is muscle memory from Zig; hint gave the fix verbatim. |
| 3 | (hint, no code surfaced) | input.kz:2 | public event declarations belong in the .k contract — move this ~pub event to the sibling .k file, or drop ~pub if it is internal scaffolding | `~pub tor a {}` in `.kz` | Teach-hit, and incidentally the diagnostic that revealed the `.k`/`.kz` duality (see below). |

## Non-diagnostic friction

**`.k` + `.kz` = one module, silently.** Ran `koruc input.k` and got
diagnostics at `input.kz:12` — reported it to the user as "stale `input.kz`
picked up." Wrong model: the `input` unit is contract `.k` + impl `.kz`
compiled together; the stale file was a legitimate half of the module and
its errors were real. Verified at `/tmp/collision`: `koruc -c input.k`
diagnoses the `.kz` sibling's contents. Nothing announces the duality when
both halves parse — the only teaching surface is the `~pub` hint (#3),
which you meet only by violating the split. Symptom for the next agent:
"compiler diagnosed a file I didn't pass" — cause: your module has two
halves. DOC.

**`koruc -c` exists; I ran full builds for every diagnostic check.**
`--check` = 0.18s on the relay probe vs ~60-90s for `koruc input -o out`
(emit + backend build). Sat in `--help` all session, unused. Behavioural
cost is compounding: to amortize build latency I batched more guessed
grammar per probe → multi-diagnostic bursts → muddier attribution (the
corpus's own caveat). If `koru-toolchain` skill doesn't name `-c` as the
probe loop, it should. DOC/discoverability.

**Grammar discovery is suite-grep.** Every construct needed this session —
`=>` producing under a `|>` arm body (`| then |> ask(q): a => done a`,
400_146), `-> T` subflow impl spelling (`name -> expr`, 020_014),
`: r` bind-then-construct (400_132), `| halved v |> subflow(v): r => done r`
relay (built fresh, verified green) — was located by grepping
`tests/regression` for a sibling. Test headers are excellent once found
(400_133's comment teaches the whole design); the index from "the shape I
want" to test name does not exist. `koru-by-example.md` is the obvious
home for a shape table. DOC.

## Reconstructed prior-arc rows (same session thread, earlier compiles)

From the summarized transcript — not re-quotable verbatim, listed for the
family count: `~` host-switch omissions in `.kz`, incomplete branch
coverage, bare-return vs named-continuation confusion on `-> string` tors,
unused bindings (KORU100 family), shadowed local names. Likely already in
sessions.db via that session's journal (koru=1252 / kopium=188 rows).

## Teach-hit note (positive data)

PARSE003 and PARSE005 are the corpus's best-behaved families for a reason:
both refusals carried the fix inside the message and both landed first-try
on the retry. The session's only real stalls were model gaps that no
refusal ever got to teach (module duality, `-c` existence) — i.e., the
diagnostics are fine; the missing surface is *outside* the refusal path.
