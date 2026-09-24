// PINS: a regex match arm's destructure delivers named groups only — it
// implements no entry annotation, so `{ [row]row, col }` refuses KORU162
// naming the field and the annotation rather than dropping it. The same
// refused-never-ignored law as store's query arm (which implements
// [row]/[ordinal]/[id], 690_069).
import std/io
import std/regex

std/regex:match("21,9")
| `(?<row>[0-9]+),(?<col>[0-9]+)` { [row]row, col } |> std/io:print.ln("row={{ row:s }} col={{ col:s }}")
| no-match |> std/io:print.ln("no")
