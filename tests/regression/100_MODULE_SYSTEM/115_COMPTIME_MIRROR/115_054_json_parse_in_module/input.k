// MIRROR for `std/json:parse` — the schema-directed parser transform
// invoked from `app/lib`, not the entry file. Entry drives it with a
// well-formed document, a malformed one, and recognizer-mode input.
import app/lib

app/lib:greet(body: "{\"name\":\"ada\",\"age\":36,\"tags\":[\"a\",\"b\"],\"junk\":{}}")
app/lib:greet(body: "{\"name\":\"zed\"}")
app/lib:scan(body: "[1,{\"a\":true},null]")
