# 800_010 — deadbolt

**Pitch:** a two-vault counting desk where money only moves while both
locks are held, the locks are seized in canonical id order, released
LIFO, and a depth guard makes any other sequence untypeable.

**Tier:** 2 — resource lifecycle / protocol.

## What it is

A desk with two `*Vault` resources (ids 2 and 1, balances 300 and 80),
one `*Guard`, and one `*Attest` notary. For eight rounds the desk
alternates transfer direction, computes a deterministic amount, peeks
both vault ids, seizes the lower id first, witnesses the attempt, runs
one `shift`, then releases in strict LIFO on **both** the `| moved`
and `| short` arms. At the base of the recursion the session itself
reads closing balances, retires both vaults and the guard, seals the
attestation, and reports.

## How Koru does the work

Three interleaved lifecycles, all enforced by phantom state:

- `*Vault<free!|held!>` — `seize` (`free → held`) and `hand-back`
  (`held → free`) are pure-Koru retags in `lib/order.k`; `shift`
  borrows `<held>`, so a free vault cannot move money; `retire-vault`
  consumes `<!free>`, so a held vault cannot be destroyed.
- `*Guard<none!|one!|two!>` — `post` (`none → one`), `pair-up`
  (`one → two`), `yield-inner` (`two → one`), `stand-down`
  (`one → none`), `retire-guard` (`<!none>`). The guard's phantom *is*
  the lock depth: the desk cannot stand down at `two` or pair at
  `none` — LIFO is the only path the types admit.
- `*Attest<open>` — borrowed (never consumed) through every recursive
  frame, sealed once at the end; `witness` and `seal-attest` are the
  only events it answers.

Custody is carried by recursion: every tor consumes the obligations at
its parameters (`<!free>`, `<!none>`) and hands them to the next call —
the language's loop-carry vehicle. Host procs in `lib/vault.kz` are
leaves only: mint, borrow-inspect, one mutating primitive, the notary
tick, and the dischargers. No lifecycle rule lives in Zig.

## Gaps filled

- The catalog's runnable Tier-2 row (`800_008_relay`) carries **one**
  resource across modules. This test carries **three simultaneous
  obligations** — two of the same type — through ~30 call boundaries,
  with an ordering protocol between them.
- Borrow-before-consume on the same binding (`id-of` on `<free>` before
  `seize` consumes it), borrow-then-borrow-again across a retag chain,
  and branch-tor resolution (`| moved` / `| short`) mid-chain inside
  record-producing arms.
- Mutual recursion among six tors carrying obligation parameters —
  the deepest consume-in/reissue-out chain in the catalog.

## Frontiers surfaced (observed and narrowed here; none pinned as
   its own test in this submission)

1. **Record-field obligations die across call boundaries** — a
   `{ f: *T<state!> }` field packed from a call-result binding (or
   returned through a recursive frame) loses tracked state for
   borrow/consume/destructure while still counting as a live debt on
   drop. The natural `{ g, lo, hi }` bundle tors this protocol wants
   are unwriteable; the `|>` chains here carry the same bindings.
2. **Emit: multi-line `-> {record}` return-type declarations are
   silently dropped** — they parse and check (stage C validates
   produces against them) but emit `Output = void`. Same-line
   declarations emit correctly. Discovered here mid-build.
3. **Emit: producing `if` can only yield a record it constructs
   literally** — `-> rec` (a captured record) collides with the
   callee's anonymous `__koru_handler_impl__struct` Output; `.{ }`
   literal repack into the declared Output is the only path. Hence
   each decision level is its own tor — every `if` sits at a
   subflow's top level, never nested.
4. **Emit: `: _` discard capture inside a subflow body** emits
   `const _ = result;` — invalid Zig (top-level `: _` is green,
   e.g. 330_107). Avoided here by leaving void steps uncaptured.

## Output

Deterministic: `amt = (i*53+17) mod 120`, direction alternates by
parity, seize order is always vault 1 first (the lower id), and round
3 shorts (vault 1 holds 30 < 56). Final: vault 2 = 216, vault 1 = 164,
7 moved / 1 short / 8 witnesses.
