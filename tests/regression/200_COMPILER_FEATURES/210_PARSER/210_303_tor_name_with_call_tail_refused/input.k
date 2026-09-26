// PINS: a tor's declared name must be one a call site can spell. `evil(x)`
// reads the parenthesised tail into the name — registering a tor under
// "evil(x)" that `evil(x)` at a call site resolves to the bare `evil` —
// so the declaration would mint a tor nothing can call, and the caller
// would eat "unknown tor" for text it never wrote.
import std/io

tor evil(x) {}
