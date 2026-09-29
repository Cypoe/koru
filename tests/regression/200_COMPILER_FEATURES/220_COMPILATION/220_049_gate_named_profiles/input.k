// Pins the named-gate surface end to end. The program itself is a decoy —
// post.sh drives `koruc input.k gate …` over the declarations this file
// carries:
//   * `gate` lists the declared profiles and their membership
//   * `gate dev` (advisory) runs the deterministic `check:` instrument and
//     reports the judgment-class row without a judge present
//   * odds-0 always misses, odds-100 always fires — the roll's verdict is
//     independent of whatever happens to be staged in the enclosing repo
//   * `gate broken` exits 1 on a failing instrument (check violations
//     always block; advisory only softens judgment rows)
//   * `gate strict --repo <scratch>` UNJUDGEs the judgment row once a real
//     staged diff exists — enforcing profile → exit 1, --advisory → exit 0
//   * `gate nosuch` refuses and names the declared set
import std/io
import std/invariants
import std/gate

std/gate:profile {
    "name": "dev",
    "block": false,
    "description": "the dev commit gate — advisory"
}

std/gate:profile {
    "name": "broken",
    "block": true,
    "description": "a profile whose instrument fails"
}

std/gate:profile {
    "name": "strict",
    "block": true,
    "description": "enforcement over a judgment-class row"
}

std/invariants:inferred {
    "name": "shape-is-named",
    "tags": ["dev"],
    "rule": "every declared shape carries a name",
    "check": "true"
}

std/invariants:inferred {
    "name": "prose-rule",
    "tags": ["dev"],
    "rule": "a judgment-class row with no check — the judge is not wired here"
}

std/invariants:inferred {
    "name": "never-fires",
    "tags": ["dev", "odds-0"],
    "rule": "a row whose alarm can never roll low enough",
    "check": "true"
}

std/invariants:inferred {
    "name": "always-fires",
    "tags": ["dev", "odds-100"],
    "rule": "a row whose alarm always rolls low enough",
    "check": "true"
}

std/invariants:inferred {
    "name": "always-fails",
    "tags": ["broken"],
    "rule": "an instrument that always exits non-zero",
    "check": "false"
}

std/invariants:inferred {
    "name": "strict-rule",
    "tags": ["strict"],
    "rule": "a judgment-class row under an enforcing profile"
}

std/io:print.ln("gate-me")
