# Probes — where the mortality law holds, and where it ends

Twelve self-contained `.mojo` files, each compiled under
`Mojo 1.2.0.dev2026091605`. The `s*` files test whether the wall is
load-bearing; the `f*` files probe the expressibility edges named in the
parent README. Every output below is verbatim.

## The wall is load-bearing

| probe | question | result |
|---|---|---|
| `s1_return` | does the obligation survive a function return? | held — the contract travels in the signature; caller must kill |
| `s2_branch` | does an if/else with one discharging arm refuse? | held — `error: 't2' abandoned…` on the else edge |
| `s3_raise` | does a `raise` path refuse? | held — same error on the raise edge |
| `s4_list` | does `List[Tx]` launder the payload? | held — `error: 'l' abandoned… Use deinit_with() to explicitly destroy a List of non-Deinitable elements` |
| `s5_field` | does a struct field launder it? | held harder — `error: field 'tx' has non-'Deinitable' type 'Tx[True]'`; the struct can't even *declare* the field without going linear itself. Contagion at declaration time |
| `s7_optional` | does `Optional[Tx]` launder it? | held — `type 'Optional' does not conditionally conform to 'Deinitable' for these parameters` |
| `s6_trait` | does boxing into `Some[AnyTx]` launder it? | held — `error: 'x' abandoned… unhandled explicitly destroyed type 'AnyTx'; note: consider adding trait conformance to Deinitable`. The existential must be killed explicitly — and if the trait *did* require `Deinitable`, the linear payload couldn't conform. Either tracked or unspellable |
| `f4_copy` | does `.copy()` mint a second debt? | held — `'b' abandoned without being explicitly destroyed`. Every copy carries its own obligation |

Also probed earlier: `_ = conn` does not launder (the discard site is the
error — the inverse of Rust's `let _ =` under `deny(unused_must_use)`).

The stdlib itself runs on this law: `Allocation` is `@explicit_destroy`
("must be consumed before it goes out of scope… prevents accidental leaks
and double-frees") with `dealloc()` and an honestly-named `unsafe_leak()`.

## Where it ends

**`s8_ptr` — raw memory is outside the law.** `unsafe_write` a linear
`Tx[True]` into a heap `Allocation`, then `dealloc` the storage: compiles,
runs, exit 0. The pointee's death is simply never checked — the checker has
no jurisdiction over raw memory. Every step is `unsafe_`-named, so the fence
is honest, but the hole is real: a resource can leave the tracked world and
its obligation evaporates with the freed storage. This is the same wall
Rust's and Koru's checkers hit — the boundary is `unsafe`, not the type
system.

**`f1_reissuer` — the checker can't tell a discharger from a re-issuer that
lies.** `use_lying(deinit self)` — a verb that consumes the channel and
releases nothing — compiles and runs clean. In Koru the return type carries
`<open!>` and the net accounting *derives* which verbs discharge (the
`440_007` axis: exec is never listed because it re-issues). In Mojo a
`deinit self` method is trusted as a death, full stop; the only safe
re-issue is one that *returns a still-linear value*, and whether a given
deinit is honest is author intent, invisible to the checker. The
`@explicit_destroy` message names verbs the author chose; it cannot name the
advancer, because there is no count to consult.

**`f3_foreign` — obligations cannot ride foreign types.** `string<open!>` has
no spelling: `Deinitable` conformance is declared at the type and cannot be
removed by a downstream user. The wrapper path works — but it is a
one-directional membrane: `leak_payload(deinit self) -> String` moves the
payload out obligation-free, compiles, runs. Linearity wraps a value; it
cannot ride one.

**`f2_ordered` — ordered discharge is expressible** (not a gap, worth
recording): `drain` gated `where not Self.drained` returning `Pipe[True]`,
`close` gated `where Self.drained` — "must call A then B" compiled and ran.
The price is one phantom parameter per ordering step, declared by hand.

## The shape of the shortfall

Inside the tracked world the law is airtight — scope, functions, branches,
raises, containers, existentials, copies all hold. The shortfalls are all at
the two edges the session predicted: **the boundary of the tracked world**
(`unsafe` raw memory, and by extension FFI) and **everything above the
death** — what the death meant, which verb did it, whether the obligation
moved. Mojo enforces mortality perfectly and understands it not at all.
