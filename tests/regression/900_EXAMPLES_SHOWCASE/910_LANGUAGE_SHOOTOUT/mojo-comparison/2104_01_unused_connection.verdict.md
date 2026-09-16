# 2104_01_unused_connection

**Command:**
```
cd mojo-comparison && pixi run --manifest-path ~/src/modular/Mojo/pixi.toml \
    mojo build 2104_01_unused_connection.mojo -o /tmp/mojocmp_2104_01
```
(Mojo 1.2.0.dev2026091605, pixi env in the `~/src/modular` source checkout.)

**mojo output (verbatim):**
```
2104_01_unused_connection.mojo:60:23: error: 'conn' abandoned without being explicitly destroyed: Connection must be used via .begin()
    var conn = connect("localhost")
                      ^
2104_01_unused_connection.mojo:60:23: warning: assignment to 'conn' was never used; assign to '_' instead?
    var conn = connect("localhost")
                      ^
mojo: error: failed to run the pass manager
```
Compilation fails. No binary is produced. Exit code: 1.

**What Mojo does:** refuses to compile. `Connection` is declared
`Deinitable where False` — it has no legal implicit destructor — so a
still-live `conn` at end of scope is a compile error, not a warning. The
trailing sentence (`Connection must be used via .begin()`) is the
`@explicit_destroy` message the type author wrote; the checker supplies the
"abandoned" verdict, the author supplies the verb list.

**What Koru does:** refuses to compile — `MUST_ERROR: "[open!] was not
discharged. Call: app.db:begin"`.

**What Rust does:** builds clean; the same mistake panics at runtime via a
hand-written drop guard (see `rust-comparison/2104_01_*.verdict.md`).

**DIFFERS: yes** — this is one of the five rows Rust loses, and Mojo wins it
outright. Where Rust needs a runtime bomb, Mojo's mortality law makes the
abandoned value unrepresentable in a compiled program. The diagnostics even
rhyme: Koru's "was not discharged. Call: …" and Mojo's "abandoned without
being explicitly destroyed: …" both name the missing verb — Koru derives it
from the obligation algebra, Mojo's is author-written text.
