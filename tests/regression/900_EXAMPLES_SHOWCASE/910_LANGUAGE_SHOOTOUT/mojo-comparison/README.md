# The same programs, now in three languages

A third column on the wall `rust-comparison/` built: the `2104_*` database
protocol — connect, begin, exec, commit XOR rollback, close — translated into
Mojo and **actually compiled**, each case carrying the command, the compiler's
output word for word, and the exit code. Nothing here is quoted from memory.

Toolchain: `Mojo 1.2.0.dev2026091605` (the 2026-09-16 nightly), run via the
pixi environment inside the `~/src/modular` source checkout at `64fcd68` —
the same checkout the analysis was read out of, so the language judged is the
language compiled. Command shape:

```
cd mojo-comparison && pixi run --manifest-path ~/src/modular/Mojo/pixi.toml \
    mojo build <case>.mojo -o /tmp/mojocmp_<case>
```

## The translation

Mojo has no obligation atoms, so the phantom states become **parameters** and
the consume/re-issue edges become **`deinit self` methods returning a
differently-parameterized value**:

```
Koru                                          Mojo
────                                          ────
Connection<connected!>                        Connection[False]
Connection<active!>                           Connection[True]
Transaction<started!>                         Tx[False]
Transaction<active!>                          Tx[True]
tx: *Transaction<!active>   (demand a state)  def commit(deinit self) where Self.active
conn: *<!connected|!active> (either state)    def begin(deinit self)          — ungated
exec -> *Transaction<active!> (re-issue)      def exec(deinit self) -> Tx[True]
<active!> dropped, close() synthesized        — no equivalent —
```

`Deinitable where False` is the whole trick: a type with no legal implicit
destructor must be killed by a *named* `deinit` method, on every CFG edge, or
the program does not compile. `commit` and `rollback` as two named
destructors is commit-XOR-rollback natively. `@explicit_destroy("…")` puts
the verb list in the diagnostic — authored text, not derived.

## The scoreboard (first batch: 9 cases)

| case | Koru | Rust | Mojo |
|---|---|---|---|
| `01` unused_connection | refuse | builds, panics at drop | **refuse** |
| `02` uncommitted_tx | refuse | builds, panics at drop | **refuse** |
| `08` close_without_transaction | refuse | refuse | refuse |
| `09` empty_transaction | refuse | refuse | refuse |
| `14` open_tx_commit_close | run | run | run |
| `15` open_tx_auto_close | **run (synthesized)** | run (Drop) | **refuse** |
| `20` open_tx_abandoned | refuse | builds, panics at drop | **refuse** |
| `21` open_tx_forgot_close | refuse (flag) | builds, silent close | **refuse** |
| `22` open_tx_exec_no_finish | refuse | builds, panics at drop | **refuse** |

- **Mojo wins all five rows Rust loses.** The abandonment cases — the ones
  where Rust can only panic at runtime from a hand-written drop guard — are
  compile errors in Mojo with no guard written at all. That is the mortality
  law doing exactly what affine types can't: refusing to let a live linear
  value reach the end of any path.
- **`_ =` does not launder.** The Rust side's sharpest finding — `let _ =`
  suppressing `#[must_use]` even under `deny` — was probed directly: in Mojo
  the discard site itself is the error. See `2104_20`'s verdict.
- **The draws are real draws.** `08`/`09` refuse with the same shape as
  Rust's `E0599` (wrong-state method call) and Koru's `Phantom state
  mismatch`. `09` carries the corpus's central claim — "can't close what you
  never used" — and `where Self.active` expresses it as directly as
  `<!active>` does.
- **`15` is the one row Mojo loses, and it loses it in kind.** Koru accepts
  the program by *synthesizing* the missing `close()` — the compiler picks a
  discharger. Mojo's regime is binary per type: `__del__` present means every
  abandonment auto-cleans (Rust's Drop), absent means none do. "Explicit
  preferred, synthesized as backstop" does not exist, and adding `__del__` to
  make this one program compile would flip every other row in the table.

## What the batch found

Mojo's model turned out to be a different point in the space, not a weaker
one: **a mortality law with no parole** — nothing escapes death, nothing is
chosen for you — against Koru's **obligation currency with a central bank** —
named atoms, consume-and-reissue netting, compiler-synthesized discharge.
Every cell above is consistent with that characterization; `15` is the row
where the difference stops being vocabulary and becomes a feature gap.

The still-unmeasured axes, for the next batch:

- **Re-issuer vs discharger (`440_007`'s shape).** Koru's `22` diagnostic
  names `tx.commit`/`tx.rollback` and pointedly *not* `tx.exec` — derived
  from net obligation accounting. Mojo names the same verbs only because the
  author wrote them into `@explicit_destroy`. A probe where a re-issuing
  method is offered as a "discharger" is where this stops being about
  diagnostic provenance and becomes a real expressibility gap — the checker
  cannot tell consume-and-remint from consume-and-release.
- **Obligations on foreign types** (`string<open!>`) — Koru mints atoms on
  stdlib types; Mojo must wrap. Expected verdict: cannot be expressed.
- **Ordered discharge** ("must call A *then* B") — expressible in principle
  via the same parameter trick (a second phantom), uncompiled.
- **Trait-object laundering** — boxing a linear type into an existential;
  the most likely soft spot in the whole design, uncompiled.
