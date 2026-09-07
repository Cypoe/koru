---
type: belief
id: frag-a-shared-library-never-absorbs-a-consumers-surface
provenance: 2026-09-06 — the pixie-voice extraction; Lars halted the session on "do we have a pixie-voice thing in our PUBLIC vercel-library?"
ts: 2026-09-06
---

# A shared library never absorbs a consumer's surface

koru-libs packages are shared instruments; a consumer's private surface
lives in the consumer and IMPORTS the library. korulang.org's pixie-voice
endpoint — the `/blog/drafts` voice gate — sat inside the public
`koru/vercel` deploy library as `vercel:api-voice` (a whole transform),
a `pixie` config field, a generated `/api/pixie-voice` route, and a
`/sounds/pixie/` URL builder. Zero other consumers existed. The site's
private feature wore a generic-looking config field in the shared
instrument, and it survived because the library is compiled constantly —
the cruft was exercised, so nothing flagged it.

The fix is structural, not editorial: the library's `vercel:site` gains a
GENERIC escape hatch — `handler_branches` (site-authored router
continuation lines) + `handler_imports` (site modules the reactor entry
imports) — and the site's voice endpoint moved into `korulang_org`'s own
`sitevoice.kz`, injected through the seam. The library knows nothing about
pixie, voice, or the site's routes; the site owns its endpoint and says so
in its own module.

The tell to halt on: a config field or transform in a shared library whose
name matches ONE consumer's product vocabulary. `pixie`, `voice`,
`korulang`, a specific site's route — if only one consumer could ever set
it, it is not library surface, it is a leak wearing a field.

What would correct this: a site feature reappearing in koru-libs (the
generic seam was not the actual mechanism, or a new one leaks), or a
consumer finding the seam cannot express a site-owned route (the generic
surface is insufficient).
