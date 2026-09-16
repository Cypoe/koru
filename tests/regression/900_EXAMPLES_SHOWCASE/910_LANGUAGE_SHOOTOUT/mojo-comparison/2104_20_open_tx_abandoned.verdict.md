# 2104_20_open_tx_abandoned

**Command:**
```
cd mojo-comparison && pixi run --manifest-path ~/src/modular/Mojo/pixi.toml \
    mojo build 2104_20_open_tx_abandoned.mojo -o /tmp/mojocmp_2104_20
```

**mojo output (verbatim):**
```
2104_20_open_tx_abandoned.mojo:49:25: error: 'tx' abandoned without being explicitly destroyed: Transaction must be finished via .commit() or .rollback()
    var tx = conn^.begin()
                        ^
2104_20_open_tx_abandoned.mojo:49:25: warning: assignment to 'tx' was never used; assign to '_' instead?
    var tx = conn^.begin()
                        ^
mojo: error: failed to run the pass manager
```
Compilation fails. No binary is produced. Exit code: 1.

**What Mojo does:** refuses to compile — the `Tx[False]` is abandoned. And
the escape hatch Rust has is closed here: writing `_ = tx` instead of
`var tx =` produces the *same* error at the discard site:

```
probe_underscore.mojo:51:9: error: 'conn' abandoned without being explicitly destroyed: Connection must be closed via .close()
    _ = conn
        ^
```

Discarding into `_` does not launder a linear value — the death still has to
be explicit. (Compare the Rust verdict on this case: `let _ =` suppresses
`#[must_use]` entirely, even under `#![deny(unused_must_use)]`.)

**What Koru does:** refuses to compile — `MUST_ERROR: "not discharged"`,
naming `started!`.

**What Rust does:** builds clean (even the `#[must_use]` lint is escapable);
panics at runtime from the drop guard.

**DIFFERS: yes** — the third Rust-loss row Mojo wins, and the strongest one:
the obvious rebuttal in both languages is "just discard it explicitly," and
only Mojo's discard still refuses.
