// Pins: `@`-prefixed entries are compiler marks — the internal pass-to-pass
// channel. They ride the AST on `marks` fields that surface syntax cannot
// reach; a user spelling one asserts pass-produced state. PARSE012 refuses
// at the binding-annotation position.
use = loop(3)
| each _[@scope] |> x
| done |> x
