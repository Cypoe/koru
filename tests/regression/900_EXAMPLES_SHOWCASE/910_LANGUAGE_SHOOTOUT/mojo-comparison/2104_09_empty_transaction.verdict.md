# 2104_09_empty_transaction

**Command:**
```
cd mojo-comparison && pixi run --manifest-path ~/src/modular/Mojo/pixi.toml \
    mojo build 2104_09_empty_transaction.mojo -o /tmp/mojocmp_2104_09
```

**mojo output (verbatim):**
```
2104_09_empty_transaction.mojo:50:20: error: invalid call to 'commit': violated constraint
    var conn2 = tx^.commit()  # Tx[False] — commit is gated to Tx[True]
2104_09_empty_transaction.mojo:34:55: note: constraint declared here evaluated to False, expected 'active'
    def commit(deinit self) -> Connection[True] where Self.active:
                                                      ^
2104_09_empty_transaction.mojo:34:9: note: function declared here
    def commit(deinit self) -> Connection[True] where Self.active:
        ^
mojo: error: failed to parse the provided Mojo source module
```
Compilation fails. No binary is produced. Exit code: 1.

**What Mojo does:** refuses to compile — `commit` is `where Self.active`
gated and `tx` is `Tx[False]`. The "you can't close what you never used"
asymmetry — the strongest claim in this corpus — survives the translation:
`begin` hands back `Tx[False]`, `commit` demands `Tx[True]`, and only `exec`
turns one into the other. A transaction opened and closed with nothing in
between is a type that cannot be spelled, in Mojo exactly as in Koru.

**What Koru does:** refuses to compile — `MUST_ERROR: "Phantom state
mismatch"`.

**What Rust does:** refuses to compile — two typestate structs, `commit()`
implemented only on the second (`E0599`).

**DIFFERS: no** — three-way draw. Notable because this row carries the
corpus's central claim, and Mojo's phantom-parameter encoding expresses the
asymmetry as directly as Koru's state chain — `where Self.active` *is* the
`<!active>` demand, minus the obligation accounting on top.
