---
type: belief
id: frag-the-observer-lane-is-chartered
provenance: 440_037/440_039 red from ac5d38b82 (the durable-cells commit),
  parked on the board "awaiting a ruling"; restored 2026-10-20 by verbatim
  revert of the removal across the bridge part-files
ts: 2026-10-20
tags: [koru, bridge, wire, observer-channel, collateral-removal]
---

# The observer lane is chartered — ungranting it is a removal, not a refactor (belief)

The wire has three lanes and they are not negotiable by diff: scope verbs act
on the world, refused prose binds as residue, and `note(text:)` — granted only
by `introspection: true` — is where a model's reasoning goes when it thinks
out loud. That lane exists because punishing narration teaches hiding, not
grammar (the kopium bench smoke measured it: full reasoning as residue died
at the rejection bound; with the lane open the same runs went 4/5).

`ac5d38b82` landed 3,533 lines of cells/fleets work and, inside it, dropped
`note` from the host table, its impl, its dispatch arm, the tail-split
rescue, and the residue classifier — five part-files, no mention in the
message, the design comments left standing. Nothing about the commit needed
the removal; `abandon` took note's slot in the table like a rename that
wasn't one.

What noticed: two regression pins and nothing else. The tests red-flagged
the removal for days while the board carried them "awaiting a ruling." The
ruling is this frag: **the granted vocabulary is the contract — a verb's
disappearance from `host_verbs` is a feature removal and belongs in the
commit that removes it, named.** A 3,500-line diff can ungrant a verb as
collateral damage precisely because the table is three lines; the only
defense is that the pins go red and someone reads them as a removal
question, not as rot to repin.

Restoration note for the next removal-catcher: the machinery is five
surfaces that must move together — the `host_verbs` row (wiregate), the
impl + dispatch arm (grants/hostverbs), the `note(...)tail` split (items),
the `isNoteAttempt` residue classifier (residue), and the four call sites
(run-exec/runsteps). Half a restore is a note that parses but binds no rN,
or dispatches but swallows its glued-on tail.
