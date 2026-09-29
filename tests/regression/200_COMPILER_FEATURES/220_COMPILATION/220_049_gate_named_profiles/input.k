// Pins the named-gate surface end to end. The program itself is a decoy —
// post.sh drives `koruc input.k gate …` over the declarations this file
// carries:
//   * `gate` lists the declared profiles and their membership
//   * `gate dev` (advisory) runs the deterministic `check:` instrument and
//     reports the judgment-class row — UNJUDGED when the profile declares
//     no judge, with the cause named
//   * odds-0 always misses, odds-100 always fires — the roll's verdict is
//     independent of whatever happens to be staged in the enclosing repo
//   * `gate broken` exits 1 on a failing instrument (check violations
//     always block; advisory only softens judgment rows)
//   * `gate strict --repo <scratch>` delegates the judgment row to the
//     profile's judge binary — VIOLATION under enforcing → exit 1,
//     --advisory → exit 0; `gate clean` pins the CLEAN verdict passing
//   * `gate nosuch` refuses and names the declared set
import std/io
import std/invariants
import std/gate

std/gate:profile(dev) {
    "block": false,
    "description": "the dev commit gate — advisory"
}

std/gate:profile(broken) {
    "block": true,
    "description": "a profile whose instrument fails"
}

std/gate:profile(strict) {
    "block": true,
    "description": "enforcement over a judgment-class row — the judge decides",
    "judge": "scratch/strict-judge"
}

std/gate:profile(clean) {
    "block": true,
    "description": "enforcement with a judge that returns CLEAN",
    "judge": "scratch/clean-judge"
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
    "rule": "a judgment-class row whose profile declares no judge"
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

std/invariants:inferred {
    "name": "clean-rule",
    "tags": ["clean"],
    "rule": "a judgment-class row whose judge returns CLEAN"
}

std/io:print.ln("gate-me")
