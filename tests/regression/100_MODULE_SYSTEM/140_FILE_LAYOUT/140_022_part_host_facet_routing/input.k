// PIN (part): a part may carry host facets of its own — `input.ping.kz`
// (Zig) and `input.ping.kjs` (JS) both join through `part ping`. The `.kjs`
// raw hostline `let ping_seen = "js-only";` is NOT valid Zig: if it leaked
// into the Zig output the backend compile would fail. Green means hostlines
// route by their own file's host, exactly as stem facets route them
// (140_010) — the part join must not flatten that.

part ping

ping()
