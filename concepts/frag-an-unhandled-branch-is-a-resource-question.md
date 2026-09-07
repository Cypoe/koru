---
type: belief
id: frag-an-unhandled-branch-is-a-resource-question
provenance: probing the interpreter's handling of partially-handled flows, 2026-08-07, after Lars asked whether a branch the interpreted source does not handle should leak to the caller — measured as 430_056
ts: 2026-08-07
---

# Totality does not lapse at the interpreter boundary — it inverts, and it is about resources (belief)

Branch totality reads as an ergonomic rule: compiled Koru makes you handle every
branch, the interpreter cannot because its source arrives after every compile
step is over, so the rule simply lapses there. That framing is wrong twice.

**It does not lapse, it inverts.** Handling NO branches is the permissive case —
the outcome comes back to the caller intact. Handling SOME is the one that
fails. So the interpreter is simultaneously more lenient and more strict than
the compiler, and which you get depends on how many arms you happened to write.
Nothing about "the rule cannot be enforced late" predicts that shape; it is not
a relaxation, it is a different rule nobody designed.

**And it is not an ergonomic question at all.** An unhandled branch may carry a
HANDLE. The moment an outcome can travel from an interpreted fragment back to
its host, "what happens to a branch nobody handled" stops being about
convenience and becomes: who owns the obligation that branch minted, and does
auto-discharge see it? A leaked `| opened` is a resource that crossed a boundary
without anyone accepting it. The compiled language has an answer for this
because it refuses the program; the interpreted one is where the question
actually arises, and it is the one place we had not asked it.

That reframing is what makes the open ruling worth taking seriously rather than
settling by taste. The leak reading is genuinely attractive — an interpreted
fragment handles what it knows and hands the rest up, so the host's own
`| result` arm becomes the outer handler, and the two compose. But it can only
be adopted alongside an answer for the obligation, and today it is the ZERO-arm
case doing exactly that with no answer attached.

The forcing function is the agent. A model writing Koru under-handles
constantly — it does not know the full branch set of a verb it was told about in
one line of prose. So whichever way this is ruled is not an edge case in the
interpreter; it is the common path for every fragment an LLM will ever send.

RESOLVED 2026-09-07 (430_056 green on wip-armed-define): both readings now
have a home. `run` gains `| unhandled-branch { branch, payload, handles }`
— the outcome leaks WITH its payload (and its named handles), not a count;
leniency is a MODE (`lenient:` on run/run-cached/eval), so strict callers get
the historical refusal and lenient hosts get the hand-back. The host MUST
handle the branch (KORU022); a model over a bridge gets it fed back — the
fragment may be partial, the program receiving partiality may not be. The
bridge is the long-running owner: auto-discharge is skipped on the hand-back
so retention across turns is the host's call, never a silent release.

Related: [[frag-a-handle-count-is-not-a-capability-check]] — the same subsystem,
the same lesson one layer down: the resource story is decided at the seams, not
by the bookkeeping that describes them afterwards.
