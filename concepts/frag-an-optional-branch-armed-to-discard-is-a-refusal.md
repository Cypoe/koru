---
type: belief
id: frag-an-optional-branch-armed-to-discard-is-a-refusal
provenance: session 2026-09-19 — KORU054 ruling (Lars: "handling an optional branch just to discard it is just a bug in the consumer code"); terminal-side sibling of KORU037 RULING 1; pinned 400_197; 68 wart sites swept across 49 files
ts: 2026-09-19
tags: [toolchain, flow-checker, optional-branches, diagnostics, consumer-spelling]
---

# An optional branch armed only to discard is a refusal, not a spelling

`| ?b |> _` is refused (KORU054); the effect twin `! ?b |> _` was already
refused (KORU037, RULING 1). An UNARMED optional branch already discards the
outcome — the spelled no-op arm adds zero semantics while reading as
"required, consciously ignored": ceremony that lies about the contract.

The hazard is promotion. If `| ?done` later becomes `| done`, a spelled no-op
arm silently satisfies the new obligation where the omitted arm would have
surfaced a must-handle error. Refusing the wart is what keeps a contract
change loud — the same reason KORU100 refuses unused bindings.

What stays legal is precise. `| b |> _` on a REQUIRED branch: the arm IS the
acknowledgement, handle-and-ignore carries meaning. `| ?b _ |> <action>`:
discarding the payload while acting is not a no-op — the body is not `_`.
Only the bare `_` body on an optional branch is refused.

## The rule judges consumer spelling — frontend only

The check (`flow_checker.checkOptionalNoopDiscard`) runs in `.frontend` mode
only, and that is load-bearing, not convenience. The frontend AST is the only
tree where every arm is user-authored: the discharge inserter's optional-arm
padding mints `binding="_"` + `.terminal` no-ops that are structurally
identical to the banned spelling — they ARE the mechanism by which "unarmed
optional discards" lowers. A structural rule that cannot tell authored text
from synthesized machinery must run where only authored text exists.

## Why it was worth a diagnostic, not a lint

68 sites across 49 suite files carried the wart before the refusal — it had
spread by cargo-cult precisely because the compiler tolerated it. Mechanical
deletion: an omitted optional and a spelled no-op lower identically, so the
sweep changes no emitted program (the omission path is pinned by 400_145).
The same spread is how the wart hid the `inline_body` arm-list freeze —
every consumer spelled the arm, so the synthesized path never ran
(frag-template-expand-freezes-before-create, second axis).

## The refusal reaches through transforms (evolved 2026-10-02)

The check used to skip `is_transform_flow` heads entirely — fan-out transforms
were presumed to carry arms as data. But a transform like `vaxis:run` forwards
its `!` arms verbatim onto a sibling decl (`step`), and those arms are
consumer-authored spelling subject to the same law. The check now runs on
transform flows, resolved against the invoked decl's MODULE vocabulary — the
arm's optionality lives on whichever sibling declares it. A data arm (regex
pattern, parser alternative) matches no declared branch and never fires.
KORU039 (sibling-discard) stays exempt: fan-out legitimately repeats names.

The sweep found the wart's true reach: 38 more sites inside transform
subtrees (capture, store:rule, regex:match, if-under-rule) that had never been
judged. Same repair — omission is identical semantics.

It also flushed out the honest case the rule was protecting against:
`vaxis`'s `! tick _ |> _` was a PRESENCE CLAIM — `@hasDecl(__H, "tick")` armed
a 16ms heartbeat. The body was `_` because the work was in the presence. The
banned spelling forced the real API: `run(tick_ms: 16)` configures the clock
directly. When a no-op arm turns out to be load-bearing, the load belongs in
the signature, not in a handler-shaped lie.
