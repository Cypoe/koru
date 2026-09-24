---
challenge: what-the-compiler-writes
kind: frame
status: standing
yields: one std transform made inspectable — an explain report that names the site, shows the rewrite, and says what it read, printed from the transform's own output where the printer can spell it
family: toolchain
created: 2026-09-21
---

*Walker context — the recurrence that earned this frame. `std/supervisor`
shipped its fold elaboration on 2026-09-21 — and in the same week shipped a
semantic hole nobody could see: the transform augmented a void branch with a
payload so a supervised site could bind it, and the blog documented the lie
as a feature (`320_167` now refuses it). The hole was invisible because the
generated vocabulary was never printed. The fix that made it visible was not
a paragraph — it was `supervisor.explain.kz`: clone the program, run the real
transform pass, print the generated items through `ast_printer`. "What did
the compiler write" became a command, not a claim.*

*Measured 2026-09-21: **37 `koru_std` files carry `[comptime|transform]`
handlers; 5 module explainers exist (list, pump, refine, store, supervisor);
exactly 1 prints the transform's output.**
20+ files mint `__`-prefixed names invisible at the site — `store.new` alone
mints 115 (`__store_announce_*`, `__store_take_*`, …), `parser.kz` 39,
`regex.kz` 26. `retarget_producer` is a public `SiteResult` flag any
transform can set — the call you wrote becomes a different call, and today
only `supervisor` is honest about it. Every other transform's rewrite is
invisible to the reader of the source.*

*`021` reads artifacts the compiler ships. This frame reads the program the
compiler *writes* — the layer between your source and the emitted Zig, where
the magic lives and where nothing is currently inspected.*

---

## The brief (sealed — you are the contestant)

**Pick a transform that rewrites what the user wrote. Make `koruc <file>
explain` show the rewrite.**

Return **1–2 transforms made inspectable**, each landed as its own commit:

1. an `[explainer]` tor (or an extension of the module's existing one) whose
   report answers, per site: **what did I write** (the site, with its
   `site_hash` witness), **what did it become** (the generated items), and
   **what did it read** (the parameters, ambient scope, or declaration the
   decision consumed);
2. the `elaborated` section where the rewrite is spellable — clone the
   program, run the real pass (`@import("root").process_all_transforms`),
   print the generated items with `ast_printer.printItemSource`. Rows you
   derive must be read off the same surfaces the transform reads — a report
   that re-interprets the source is a second transform and will lie
   (`frag-an-explainer-runs-the-transforms-fold-not-a-second-reading`);
3. a regression pin under the transform's own cluster that runs `explain`
   in `post.sh` and matches the report — the pattern is
   `320_168_supervised_explain_reports`.

An explainer you wrote but did not land is a lead, not a deliverable.

## The ladder — how invisible is the rewrite

Rank the transform you pick by what it does to the user's text. Higher is
worth more:

1. **Retargets.** The call you wrote becomes a different call —
   `SiteResult.retarget_producer`. Today only `supervisor` sets it; finding
   a second caller is itself a finding.
2. **Mints names.** Decls appear that you never wrote — `store.new`'s 115
   `__store_*` decls, `pump`'s `__pump_<name>_step_<i>`, parser's grammar
   tors. The reader's grep cannot find them because the reader's grep is on
   source.
3. **Rewrites in place.** Same shape, different content — a guard lowered
   to a sweep, a facet met to a check, a mock swapped for a call.
4. **Augments.** Adds arms, checks, or branches; the user's vocabulary
   survives verbatim. Least magical — and still worth a row, because the
   added arms are invisible at the site too.

## The findings this frame wants most

- **A transform whose output the printer cannot spell.** `ast_printer`
  refuses nodes with no surface form (`UnprintableNode`). If a transform
  emits one, either the printer has a gap or the language does — a shape
  the compiler produces that a user could never write. Pin it, name it,
  report which it is.
- **A derived row that disagrees with the elaborated print.** If the report
  says one thing and the transform's own output says another, the explainer
  is lying — fix the explainer, not the story.
- **An `elaborated` section that does not re-parse.** The printed program
  should compile back; if it does not, the print is decoration, not
  evidence. Say so.
- **A transform whose rewrite depends on another transform having run
  first.** `process_all_transforms` on a clone runs the whole pass — if the
  interesting rewrite only appears in sequence, the honest report says what
  ran before it.

## Out of scope

- A generic `koruc <file> --elaborated` flag dumping the whole
  post-transform program — deliberately deferred; this frame wants
  per-site reports, not a second file to diff against.
- Explaining programs that do not import `std/explain` — the command
  gathers what is declared; a program without it has no report by design.
- Judging whether the transform *should* rewrite — that is `024`'s hunt.
  This frame only makes the rewrite visible.

*Naming: after the blog section that started it —
`korulang_org/src/routes/blog/a-supervisor-is-a-while-loop/+page.svx`,
"What the compiler writes."*
