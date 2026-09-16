# 2104_15_open_tx_auto_close

**Command:**
```
cd mojo-comparison && pixi run --manifest-path ~/src/modular/Mojo/pixi.toml \
    mojo build 2104_15_open_tx_auto_close.mojo -o /tmp/mojocmp_2104_15
```

**mojo output (verbatim):**
```
2104_15_open_tx_auto_close.mojo:57:28: error: 'conn2' abandoned without being explicitly destroyed: Connection must be closed via .close()
    var conn2 = tx2^.commit()
                           ^
2104_15_open_tx_auto_close.mojo:57:28: warning: assignment to 'conn2' was never used; assign to '_' instead?
    var conn2 = tx2^.commit()
                           ^
mojo: error: failed to run the pass manager
```
Compilation fails. No binary is produced. Exit code: 1.

**What Mojo does:** refuses to compile — `conn2` is `Connection[True]`,
linear, and dropped. This is the row where the regimes differ in kind. Mojo's
linearity is a *mortality law*: a type either has a legal implicit destructor
(`__del__` → `Deinitable`, every abandonment silently cleans up — Rust's Drop
shape) or it has none and must be killed by name. There is no third regime,
no "explicit preferred, synthesized as backstop." To make this program
compile you would have to add `__del__` to `Connection` — which would flip
*every* row in this directory, not just this one.

**What Koru does:** accepts — `MUST_RUN`, prints the same trace as `14`. The
auto-discharge inserter sees the `<active!>` obligation dropped at `:_` and
synthesizes the `close()` call itself. Koru is the only one of the three
that can *write the discharger for you* — and per `440_007`, choosing the
right one is the hard part (a re-issuer is not a discharger).

**What Rust does:** accepts — `Drop` on `Connection` runs the close at scope
exit, as an ordinary consequence of ownership.

**DIFFERS: yes — Mojo is stricter than both.** Rust accepts by default-drop,
Koru accepts by synthesis; Mojo refuses outright. The honest reading cuts
both ways: Mojo's binary regime means the synthesized-cleanup feature is
inexpressible *without weakening every other guarantee on the type* — Koru
keeps the mandate AND fills in the verb; Mojo makes you pick one regime per
type, forever.
