// Pins the single-block cap: std/compress:gzip is a one-shot block emitter
// (INPUT_CAP = 65535, the DEFLATE stored-block limit the token format
// inherits); bodies at or above it take the `error` branch with the honest
// refusal rather than truncating or silently falling back to zlib — the
// caller owns that choice. input.txt is 69,624 bytes of repeated-key JSON.

import std/io
import std/compress

std/io:read-file(path: "tests/regression/600_STDLIB/643_COMPRESS/643_003_gzip_input_cap/input.txt")
| not-found |> std/io:print.ln("fixture missing")
| failed e |> std/io:print.ln("read failed {{ e:s }}")
| ok content |> std/compress:gzip(data: content)
    | compressed { data, original_size } |> std/io:print.ln("UNEXPECTED compressed {{ original_size:d }}->{{ data.len:d }}")
        |> std/io:free(content)
    | error e2 |> std/io:print.ln("cap {{ e2:s }}")
        |> std/io:free(content)
