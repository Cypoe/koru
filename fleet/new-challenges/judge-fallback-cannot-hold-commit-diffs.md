---
status: standing
kind: generator
filed-by: fleet pilot round (Q3 attempt), 2026-10-27
---

# The judgment gate's fallback judge cannot hold a commit-sized diff

## The gap

`gate.py` and the in-language gate treat `UNJUDGED` as blocking when
enforcing — correctly, "never a silent pass". But the only locally
provisionable judge is LM Studio `laya` (a ~300M BERT decisions model
behind `/v1/systemone`), whose physical batch size is 8192 tokens. A
normal commit diff is 10–40k tokens. So on any host without an
OpenRouter key, every commit hits 4 hard blocks with no recourse:
`lms` refuses batch-size config for non-LLM model classes.

Measured 2026-10-27: 10,156-byte staged diff → 20,236 tokens →
HTTP 500 `input (15020 tokens) is too large to process` on a 4k
subsystem payload probe; the same endpoint judged small payloads fine.

## Yield

One of:

- **Chunked judgment** — split the state at file boundaries and judge
  per-hunk, with the verdict combinator defined in the row's contract
  (any VIOLATION = violation; all CLEAN = clean; size-elision already
  exists per-file). Design decision: does per-hunk judgment blind rules
  that need cross-file context (e.g. surface-spellings)?
- **A provisionable fallback model** — an OpenRouter-free judge that
  fits on this class of hardware AND holds 96KB state, or the honest
  ruling that the fallback is unreachable and `--checks-only` is the
  documented offline mode (in which case `gate.py`'s "no offline mode"
  refusal message is the stale claim).
- **Smaller judged state** — `judge-additions`-style narrowing for the
  remaining rows, or diff-stat + per-file on-demand expansion.

Evidence to replay: `invariants/gate.py` JUDGE_STATE_MAX_BYTES comment,
`koru_std/gate.kz` lines ~456-470, `koru/odds` index.kz judgeTarget.
