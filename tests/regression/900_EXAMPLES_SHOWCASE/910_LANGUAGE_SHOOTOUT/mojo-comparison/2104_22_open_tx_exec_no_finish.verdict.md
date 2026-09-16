# 2104_22_open_tx_exec_no_finish

**Command:**
```
cd mojo-comparison && pixi run --manifest-path ~/src/modular/Mojo/pixi.toml \
    mojo build 2104_22_open_tx_exec_no_finish.mojo -o /tmp/mojocmp_2104_22
```

**mojo output (verbatim):**
```
2104_22_open_tx_exec_no_finish.mojo:54:23: error: 'tx2' abandoned without being explicitly destroyed: Transaction must be finished via .commit() or .rollback()
    var tx2 = tx^.exec("INSERT INTO users VALUES (1, 'alice')")
                      ^
2104_22_open_tx_exec_no_finish.mojo:54:23: warning: assignment to 'tx2' was never used; assign to '_' instead?
    var tx2 = tx^.exec("INSERT INTO users VALUES (1, 'alice')")
                      ^
mojo: error: failed to run the pass manager
```
Compilation fails. No binary is produced. Exit code: 1.

**What Mojo does:** refuses to compile — `exec` consumed `Tx[False]` and
returned `Tx[True]`, a live linear value that still must be explicitly
destroyed. Note where the error lands: on the `exec` call's result binding,
not on `begin`'s — last-use dataflow tracks the *reissued* value, the same
way Koru's obligation survives the consume and lands on the new binding.

**What Koru does:** refuses to compile — `MUST_ERROR` pins the diagnostic to
name `tx.commit` and `tx.rollback` and to *not* name `tx.exec`: the checker
knows exec re-issues the obligation (net nonzero) and is therefore not a
discharger. Mojo's message names the same two verbs — but only because the
`@explicit_destroy` string was authored that way. The checker cannot tell a
re-issuer from a discharger; that distinction is the entire `440_007` axis,
and on this batch it stays unmeasurable: both compilers refuse, one of them
knows why.

**What Rust does:** builds clean; panics at runtime from the drop guard.

**DIFFERS: yes** — the fifth Rust-loss row Mojo wins statically. The row also
marks the edge of what the comparison can see: the refusal is identical, but
Koru's is *derived* (the obligation algebra picks the legal exits) while
Mojo's is *asserted* (author-written text under a mechanical "must die").
