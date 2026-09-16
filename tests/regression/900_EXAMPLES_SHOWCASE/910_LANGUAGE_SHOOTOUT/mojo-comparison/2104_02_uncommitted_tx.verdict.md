# 2104_02_uncommitted_tx

**Command:**
```
cd mojo-comparison && pixi run --manifest-path ~/src/modular/Mojo/pixi.toml \
    mojo build 2104_02_uncommitted_tx.mojo -o /tmp/mojocmp_2104_02
```

**mojo output (verbatim):**
```
2104_02_uncommitted_tx.mojo:64:25: error: 'tx' abandoned without being explicitly destroyed: Transaction must be finished via .commit() or .rollback()
    var tx = conn^.begin()
                        ^
2104_02_uncommitted_tx.mojo:64:25: warning: assignment to 'tx' was never used; assign to '_' instead?
    var tx = conn^.begin()
                        ^
mojo: error: failed to run the pass manager
```
Compilation fails. No binary is produced. Exit code: 1.

**What Mojo does:** refuses to compile — `tx` is `Tx[False]` (started), a
linear type with no legal drop. The phantom parameter is doing double duty
here: even if `tx` *were* touched, the only methods callable on `Tx[False]`
are `exec` (which remints to `Tx[True]`) — `commit`/`rollback` are
`where Self.active`-gated away, so the tx could never reach a legal death
without work first.

**What Koru does:** refuses to compile — `MUST_ERROR: "<started!> was not
discharged"`, and the diagnostic adds "Call: exec" — the checker names the
step that advances the obligation, not just the ones that discharge it.

**What Rust does:** builds clean, panics at runtime from the drop guard.

**DIFFERS: yes** — second Rust-loss row that Mojo wins statically. One honest
difference in the diagnostics: Koru names `exec` (the *advancer*) because its
obligation algebra distinguishes "re-issues nonzero" from "discharges"; Mojo
names `commit`/`rollback` only because that is the string the author wrote
into `@explicit_destroy` — the checker knows nothing about which verbs are
legal, only that the value must die.
