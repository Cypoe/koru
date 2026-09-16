# 2104_08_close_without_transaction

**Command:**
```
cd mojo-comparison && pixi run --manifest-path ~/src/modular/Mojo/pixi.toml \
    mojo build 2104_08_close_without_transaction.mojo -o /tmp/mojocmp_2104_08
```

**mojo output (verbatim):**
```
2104_08_close_without_transaction.mojo:49:10: error: invalid call to 'close': violated constraint
    conn^.close()  # Connection[False] — close is gated to Connection[True]
2104_08_close_without_transaction.mojo:19:34: note: constraint declared here evaluated to False, expected 'used'
    def close(deinit self) where Self.used:
                                 ^
2104_08_close_without_transaction.mojo:19:9: note: function declared here
    def close(deinit self) where Self.used:
        ^
mojo: error: failed to parse the provided Mojo source module
```
Compilation fails. No binary is produced. Exit code: 1.

**What Mojo does:** refuses to compile — `close` is `where Self.used`-gated,
so on `Connection[False]` the call is a constraint violation. This is plain
parametric dispatch: the wrong-state call is unspellable, same mechanism as
Rust's `E0599 no method named close`.

**What Koru does:** refuses to compile — `MUST_ERROR: "Phantom state
mismatch"` (<!active> demanded, <connected!> held).

**What Rust does:** refuses to compile — `E0599`, method exists only on the
other typestate.

**DIFFERS: no** — a three-way draw, and the diagnostics are near-identical in
shape: all three name the call site and point back at the gate that refused
it. The interesting nuance is what the gate *is*: Rust's is impl-block
membership, Mojo's is a `where` clause on the same method, Koru's is a
phantom-state pattern in the parameter type.
