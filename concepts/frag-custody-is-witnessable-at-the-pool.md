---
type: belief
id: frag-custody-is-witnessable-at-the-pool
provenance: kopium custody-record session 2026-10 — SCENE chartered "the
  resource world is a place a successor can inspect" and the fog-of-war line
  called history "named, not designed"; this is the designed organ
ts: 2026-10-13
tags: [koru, kopium, obligations, custody, provenance, world]
---

# Custody is witnessable at the pool — mint and release each funnel through one site (belief)

The resource world's provenance turned out to need no instrumentation pass
over the interpreter, because `HandlePool` already enforced custody at two
synchronous funnels: every mint is `acquire`, every release is
`dischargeById`/`discharge` (explicit verbs, the AUTO-DISCHARGE sweep, and
hang-up all route through them). A single optional callback on the pool —
`on_custody(kind, handle, subject)` — therefore sees *every* custody edge
without touching a call site. Possession enforcement stays the source of
truth; the witness only observes.

Three design facts the implementation surfaced:

- **The subject is the evaluated args, not a prose label.** `custodySubject`
  renders `name=value` at the dispatch site where the args still exist; the
  pool stores no copy — the witness is synchronous and the slice dies with
  the call. "The why of the possess" is what the verb actually took.
- **The record is faithful to obligation churn, not logical fds.** A
  consume-and-reissue verb (`append` mints a fresh `<open!>`) writes a
  mint/release pair per churn — a successor counting "holds" must group by
  handle id, which is exactly the ambiguity the record refuses to paper
  over.
- **Death is legible by omission.** A `session-open`/`session-closed` pair
  bounds each span; a mint inside a closed span with no release was
  discharged at hang-up, and a mint with no `session-closed` after it died
  with the process. Because records append per event, a kill leaves an
  open span a successor can still read — no fsync protocol, no checkpoint.

The bridge installs the witness only when `world != null`
(`armCustodyLog` in `bridge.custody.kz`); a worldless bridge writes no log.
`holds.log` sits next to the vocabulary file — heredity's world-state and
vocabulary channels gain a third: *events*.

## Where this could be wrong

- If a mint or release ever bypasses the two funnels (a fast-path that
  mutates `discharged` inline, a second pool), the witness silently
  under-reports — the funnel count is the invariant to defend, and a grep
  for direct `.discharged = true` is the check.
- `subject` is bounded at 192 bytes and truncates mid-list; verbs with
  huge arg payloads would need a richer subject story.
- Wall-clock timestamps make ordering self-evident but a multi-process
  world (two sessions mounting concurrently) has no interleave discipline
  — appends are line-level and the file is append-only, which is the
  honest floor, not a lock.

**The record gained an independent reader.** `verify/holds/HoldsCheck.lean`
re-decides the whole vocabulary line-by-line against a session-span ledger
— `lean --run` over `holds.log` — with the ledger proved to agree with an
independent right-to-left reference scan at every accepted prefix
(`step_inv`, `replay_all`), and `clean_sound` certifying that a clean file
leaves nothing held anywhere and that every release was backed by a live
mint at its position. Two rulings the checker surfaced: `unreleased-at-close`
records the violation *and* applies the close — the close did happen, so
the record reflects it — and `use` remains outside the vocabulary: borrow
specs never reach the pool callback, so exercising a held handle is
enforced (`assertHandlesHeld` at dispatch) but unwritten. That is the last
unwitnessed edge class; extending the vocabulary is the R2 question, for
Lars's eyes.
