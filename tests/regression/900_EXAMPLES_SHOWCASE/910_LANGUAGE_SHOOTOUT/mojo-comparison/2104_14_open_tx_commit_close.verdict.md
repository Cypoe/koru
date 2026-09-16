# 2104_14_open_tx_commit_close (positive control)

**Command:**
```
cd mojo-comparison && pixi run --manifest-path ~/src/modular/Mojo/pixi.toml \
    mojo build 2104_14_open_tx_commit_close.mojo -o /tmp/mojocmp_2104_14 \
    && /tmp/mojocmp_2104_14
```

**mojo output:** compiled cleanly, no diagnostics. Exit code: 0.

**Program output (`/tmp/mojocmp_2104_14`, exit 0):**
```
Executing: INSERT INTO users VALUES (1, 'alice')
COMMIT
Connection closed
```

Byte-identical to the Koru test's `expected.txt`.

**What Mojo does:** accepts the full protocol — open, begin, exec, commit,
close — and runs it. The phantom state machine costs nothing at runtime:
`Connection[False]` and `Connection[True]` are the same one-word struct; the
parameter exists only inside the checker and is gone by codegen.

**What Koru does:** accepts — `MUST_RUN`, same three lines.

**What Rust does:** accepts — same trace.

**DIFFERS: no** — all three accept the happy path. This file is the column's
control: it proves the `.mojo` model in the other eight cases is a working
program, not eight files that all fail for some unrelated reason.
