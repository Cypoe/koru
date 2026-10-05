---
type: belief
id: frag-presence-and-liveness-are-different-facts
provenance: stack declares `requires.system` for docker; `docker --version`
  answers installed while `stack up` needs the daemon alive — the deps
  vocabulary had no way to say the second thing
ts: 2026-10-05
tags: [deps, toolchain-vocabulary, three-states]
---

# Presence and liveness are different facts with different remedies (belief)

`requires.system`'s `check` field answers *installed*; nothing answered
*usable now*. Those are different facts: `brew install docker` cannot start
the daemon, and reporting a down daemon as "missing" invites a reinstall that
fixes nothing. A `ready` field carries the liveness probe — a command whose
exit 0 means usable — and `deps` reports a third state: `installed, not
ready`, kept out of the `missing` bucket so the install path never pretends
it can repair liveness.

The shape mirrors the vocabulary one layer down: compose's
`service_started` vs `service_healthy` is the same two-phase split inside
the stack; `check`/`ready` is the same split between the host and the
substrate. Probes answer in exit codes — `pg_isready`, `docker info`,
`redis-cli ping` — not output matching; an `expect` field would add brittle
parsing to a binary question.

Pinned by 310_139.
