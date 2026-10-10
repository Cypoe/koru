// MIRROR for `std/json:emit` — the schema-directed emission transform
// invoked from `app/lib`, not the entry file.
import app/lib

app/lib:roundtrip(body: "{\"service\":\"orisha\",\"port\":8080,\"tls\":true}")
