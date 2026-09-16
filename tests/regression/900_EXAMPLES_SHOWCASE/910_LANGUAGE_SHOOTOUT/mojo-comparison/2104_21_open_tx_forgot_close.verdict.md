# 2104_21_open_tx_forgot_close

**Command:**
```
cd mojo-comparison && pixi run --manifest-path ~/src/modular/Mojo/pixi.toml \
    mojo build 2104_21_open_tx_forgot_close.mojo -o /tmp/mojocmp_2104_21
```

**mojo output (verbatim):**
```
2104_21_open_tx_forgot_close.mojo:55:28: error: 'conn2' abandoned without being explicitly destroyed: Connection must be closed via .close()
    var conn2 = tx2^.commit()
                           ^
2104_21_open_tx_forgot_close.mojo:55:28: warning: assignment to 'conn2' was never used; assign to '_' instead?
    var conn2 = tx2^.commit()
                           ^
mojo: error: failed to run the pass manager
```
Compilation fails. No binary is produced. Exit code: 1.

**What Mojo does:** refuses to compile — identical output to `2104_15`,
because the program text is identical. The difference between the two Koru
tests is a flag, `--auto-discharge=disable`; Mojo has no flag because it has
no auto mode to disable. The refusal is unconditional on every CFG edge.

**What Koru does:** refuses under the flag — `MUST_ERROR: "<active!> was not
discharged"`. (Without the flag it is `2104_15` and runs.)

**What Rust does:** builds clean; a `Drop` impl closes the connection
silently at scope exit — Rust cannot distinguish "forgot to close" from
"intended the drop."

**DIFFERS: yes** — the fourth Rust-loss row Mojo wins. Worth saying plainly:
Mojo's win here and Koru's flagged refusal are the *same* guarantee; the
difference is Koru's flag exists because Koru also offers the auto mode `15`
exercises. Mojo's refusal is not a stricter choice, it is the only mode the
type system has.
