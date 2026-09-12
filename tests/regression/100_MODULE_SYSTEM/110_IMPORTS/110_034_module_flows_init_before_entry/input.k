// Pins that an imported module's top-level flows run BEFORE the entry file's
// own flows. The module seeds `items` at top level; the entry's flow calls
// the module's `show` tor and must already see both rows. Emitting module
// flows after the entry's flows — the shape this caught — runs the entry's
// world-facing code against an uninitialized module (found via koru-libs
// games/ponkatris: the engine module seeded its world store at top level,
// but the entry's tick loop ran first on an empty store).

import mymod

mymod:show()
