# 620_013 — fmt:ln scoped param laundering

`scratch@scoped` on `fmt:ln`'s product refuses direct produce (`-> l`,
`-> l.text`, record literals, `=>` payloads — 620_011). Before declared
class conferral, the same escape survived through a parameter:

```koru
identity = std/io:print.ln(data) -> data
```

`identity(data: l.text)` compiled because the arg wall resolved the
projection by suffix (a binding ending in `.text`) and missed that `l` —
the carrier — is the tracked, classed binding. Inside `identity`, `data`
bound unqualified `string`, so `-> data` produced the borrow back to the
caller holding an unqualified alias.

## What closed it

Declared class conferral, two mechanics and a ruling:

1. **Prefix resolution at the arg wall** — `l.text` resolves its carrier
   `l`'s phantom (descends-from a classed binding, the same walk the
   produce-edge check does), so a scoped argument is *seen* as scoped.
2. **The arg wall enforces declared class acceptance** — `string` and
   `string<*>` refuse a scoped argument with a teaching hint; only a param
   that declares `string<*@scoped>` (any identity + the `scoped` class)
   accepts it.
3. **Conferral is declared, not inferred** — bodies are checked once per
   decl, so the param's declared phantom lands on the callee binding:
   `data: string<*@scoped>` binds `data` scoped inside, and `-> data` from
   such a param is refused at the callee's own produce edge unless the
   declared output itself carries `scoped` (`-> string<*@scoped>` is a
   class-preserving reissue — the caller's binding stays scoped).

The strict ruling (unqualified params accept, callee re-binds unqualified)
was rejected: it would re-create the launder this test pins. Refusing at
the wall means a tor that wants to tunnel a borrow through must say so on
the declaration — the contract, not the call site, carries the class.

`expected_error.txt` pins the wall diagnostic: the param `declares no
scoped acceptance`.
