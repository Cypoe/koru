---
type: belief
id: frag-a-tool-reports-what-it-did-not-what-it-skipped
provenance: Lars, 2026-07-31, on `✓ Command finished (no executable built)`
ts: 2026-07-31
---

# A tool's output states the act it performed; the bug it no longer has is not part of its vocabulary (belief)

`koruc app.k deps` used to end with `✓ Built executable: a.out` when no
executable had been built. The first fix replaced it with:

    ✓ Command finished (no executable built)

Truthful, and still wrong. The parenthetical exists only because of the previous
defect. A reader who never saw the bug is being told about the absence of a thing
they had no reason to expect, in the terminal line that should have told them
what happened. The right output names the act:

    ✓ deps

## The failure mode this belongs to

Call it **compensation prose**: carrying a fixed bug forward into the permanent
voice of the tool. It is easy to write because, at the moment of the fix, the
absence is the most salient fact in the author's mind — the bug was just
diagnosed, the wrong claim was just removed, and stating "this did NOT happen"
feels like the correction. It is not. It is the author's debugging history
leaking into the user's interface.

The tell is a negation, a parenthetical caveat, or a clause explaining what the
tool is *not* claiming. Each is a sentence about a past defect wearing the
costume of a status message.

It generalises past CLI output to anywhere a durable artifact is written near a
fresh fix — a comment justifying why a line is not wrong, a doc paragraph warning
about a failure that can no longer occur, a diagnostic that mentions what it used
to say. The same fix in this commit removed a fifteen-line comment doing exactly
that.

## Why the positive form is also more correct

It is not only a matter of tone. `✓ deps` is derived from what the compiler
actually ran (`detected_comptime_command`), so it stays true as the pipeline
changes. `(no executable built)` is derived from the shape of one historical bug,
so it goes stale the moment the reason for having no executable changes — and it
would then be a second wrong claim written to prevent a first.

Positive statements are checkable against the machine. Statements about absence
usually are not, which is how they rot silently.

Distinct from [[frag-a-failure-that-looks-like-success-is-unfalsifiable]]: that
belief is about a surface unable to reveal a problem, this one about a surface
that reveals a problem nobody has. They meet at the same discipline — say the
fact, derived from the artifact.

## Open

There is no positive fact available when the backend exits cleanly, no command
ran, and no executable exists. That branch now prints nothing at all. Silence is
the right default over narrating an absence, but whether that state is reachable
— and whether it should be an error rather than silence — is unexamined.

The same belief one level up: the act includes the MODE it ran in
(2026-09-21). `koruc prog.k` built Debug and `✓ Compiled to a.out` said
nothing about it — a truthful line that left the act under-specified,
which is how a benchmark ended up timing a bounds-checked binary at 21x
the ReleaseFast number. The Debug default is a deliberate ruling (the
suite must judge checked code); silence was the defect. The success line
now names the mode — `✓ Compiled to a.out (Debug)` — on both the
build-file and build-exe paths and on the outer `Built executable` line.
905_build_mode_names_itself pins the Debug banner; the ruling stands, the
invisibility does not.

The belief's other half arrived the same evening (2026-09-21): a reported
act nobody checks is still a hole. Four of the repo's five benchmark entry
points — 003's board plus its Bevy anchor, 004, 005, and osprey's closer in
koru-benchmarks — invoked `koruc` with no flag at all, so every one of them
timed Debug binaries against `-O ReleaseFast` and `cargo --release` anchors.
They were written while ReleaseFast was still the default; the ruling flip
made each of them silently wrong without touching a line. The committed
results.jsonl predates the flip — the trap was live, that artifact was not
its victim — but nothing stood between the next run and a published Debug
number. The fix is not trust but assertion: each script passes
`--release=fast` AND greps the build output for `(ReleaseFast)`, refusing
to time otherwise. The tool names the act; the harness refuses to proceed
on any other act. A benchmark that cannot state its build mode is a number
generator, not a measurement.
