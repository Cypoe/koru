// PINS: a label declaration carries no argument list. `@done(r: {...})` reads
// the whole tail as the label's NAME — minting a label no `@name` jump can
// spell — so the declaration is refused as malformed rather than registered.
import std/io

@done(r: {a: 1, a: 2})
