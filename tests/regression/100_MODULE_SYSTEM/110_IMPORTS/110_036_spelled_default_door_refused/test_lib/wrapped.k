// A module whose own body spells the door — the imported-module pass refuses
// it with the same diagnostic as the entry-file spelling.
import lib/door

lib/door:default(name: "wrapped")
