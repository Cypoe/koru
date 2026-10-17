# 620_013 — fmt:ln scoped param laundering (aspirational)

`scratch@scoped` on `fmt:ln`'s product refuses direct produce (`-> l`,
`-> l.text`, record literals, `=>` payloads — 620_011). What it does not yet
refuse is the same escape through a parameter:

```koru
identity = std/io:print.ln(data) -> data
```

`identity(data: l.text)` compiles today because the arg wall resolves the
projection by suffix (a binding ending in `.text`) and misses that `l` — the
carrier — is the tracked, classed binding. Inside `identity`, `data` binds
unqualified `string`, so `-> data` produces the borrow back to the caller,
who now holds an unqualified alias that can leave the frame.

## What closes this

Two mechanics plus a ruling, named in the commit thread for c37503911:

1. **Prefix resolution at the arg wall** — `l.text` must resolve its carrier
   `l`'s phantom the way the produce-edge check already does (descends-from a
   classed binding), not only suffix-match for renamed field bindings.
2. **Class conferral through parameter binding** — the arg's classes land on
   the callee's param binding regardless of the declared annotation. A class
   is a property of the value, not of the contract.
3. **The ruling** — what the acceptance wall does with a class-only phantom:
   strict (unqualified params refuse; consumers re-declare `string<*>`) vs
   conferral (class-only values pass — the wall exists for debts — and bind
   with the class). The pinned diagnostic text below assumes conferral;
   under strict the refusal fires at the call wall instead and says
   "accepts only unqualified".

`expected_error.txt` pins the conferral shape: `'data' is @scoped`. If the
strict ruling wins, the pin's text changes — the program still refuses
somewhere, which is all this test exists to decide.
