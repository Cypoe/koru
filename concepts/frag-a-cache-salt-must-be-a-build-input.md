---
type: belief
id: frag-a-cache-salt-must-be-a-build-input
provenance: 2026-09-17 — asked why $TMPDIR/koru-regression-cache was 256 GB; measured 32.7 GB with no eviction anywhere, and an mtime salt minting a dead generation per compiler rebuild
ts: 2026-09-17
---

# A build cache's salt must be a build input (belief)

A key is `salt + inputs`, and the salt is where the *coarse* invalidation lives:
"this whole family of entries is dead." That framing invites the mistake, because
a coarse guard feels safe in one direction only. The backend cache's salt was the
newest **mtime** across the compiler sources plus the built `koruc` binary. Every
edit, every touch, every rebuild of the compiler advanced it.

The two failure modes of a bad key are not symmetric. An unfaithful *key* serves
poison — the neighbouring belief is that whole story. An unfaithful *salt* cannot:
it only misses, and the entries stay on disk. So it hides. Measured in one
checkout on 2026-09-17: 1088 fresh entries / 11.25 GB in 21.7 hours — nine
generations in a day, each one a full rebuild of the ~121 backends the cache
existed to skip. **The leak and the uselessness are the same event**, and the
second half is invisible: nothing reports that a cache stopped caching, and a miss
looks exactly like a cold cache.

**Mtime is not a build input.** That is the belief. Content is — (relpath, bytes),
names first so that a rename carrying identical bytes still moves the salt. The
fingerprint is also *cheaper* than the census it replaced (2.18 s vs 2.91 s over
the 268-file tree), so a cost argument for the proxy never existed; it was chosen
because a max-mtime is one line and reads as conservative.

**Where it was found is the sharper half.** This mistake had already been found,
fixed, and written down: the neighbouring belief records mtime *keying* serving a
poisoned backend, and the content-hash fix landed 2026-08-15. The salt is the
**second site** of the same mistake inside the same feature, and it survived that
fix by a month — because the fix went to the code that failed rather than to the
idea that failed. Fixing an instance does not close a class: the instance is where
it was noticed, not where it lives. Look for the *mechanism* elsewhere in the
feature — here, "something in this cache is keyed on mtime" was true in two
places, and only one of them had a failing symptom.

Falsifiable edge: if hashing the tree ever became the expensive part of a suite
start, or if two genuinely different trees ever collided under it, this is
corrected. Neither is close — the hash is about 2% of a suite's wall time.

## Related

- `frag-a-backend-cache-keyed-on-mtime-can-serve-poison` — the same mistake one
  site over, where it miscompiled instead of leaking. Read the pair together: one
  belief is "an unfaithful key serves wrong answers", this one is "an unfaithful
  salt serves no answers and says nothing".
