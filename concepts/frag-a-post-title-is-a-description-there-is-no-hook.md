---
type: belief
id: frag-a-post-title-is-a-description-there-is-no-hook
provenance: Lars-ruled 2026-10-03 — "there is just a title that describes the contents of the blog post" — after the sqlite benchmark post shipped a draft titled "Orisha: The Cold Path Is the Library" at slug the-cold-path-is-the-library: subject-led, gate-clean, and still unreadable to anyone scanning the index.
ts: 2026-10-03
---

# A post title is a description of its contents; there is no hook slot (belief)

A korulang.org title tells a scanning reader what the post covers — nothing
more is in the slot. The 2026-07-15 ruling ("subject leads, hook rides
behind") fixed the *lead* but legitimized the *hook*, and hooks stayed
cryptic: "Orisha: The Cold Path Is the Library" passed the wall while naming
a metaphor instead of a benchmark. The correction removes the second half of
the form entirely — a colon is allowed only when what follows is still a
plain description.

## The slug is the title, kebab-cased

The directory name is the post's address — it shows in every link before a
word of the post does. It is built from the title's own words and must name
the subject; it is never a private name for the piece.
`check-post-publication` enforces both: the title must open with the subject
at a word boundary, every contentful slug token must appear in the title
(singular drift tolerated), and a subject token must be present in the slug.
Same trigger moments as the title wall — new post, retitle, `subject:`
change — and the same unforgiving tier.

## Boundary

This governs the site's authored naming surface (title, subject, slug). It
says nothing about prose voice, which stays — wit lives in the excerpt and
the body. Legacy posts are not retro-renamed; the gate fires only when a
title or subject is written or changed.
