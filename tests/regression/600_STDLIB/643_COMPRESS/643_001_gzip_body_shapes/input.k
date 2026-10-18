// Pins std/compress:gzip across body shapes — the tor's `compressed` branch
// carries {data, original_size}; `std/compress:crc32` pins the emitted
// stream's exact bytes as a number (the encoder is deterministic: same
// input, same tree, same stream). Lengths pin block-type selection: the
// near-empty bodies take the fixed-Huffman path, the repeated-JSON body
// earns a dynamic block.

import std/io
import std/compress

// empty body — valid gzip stream, header+trailer only
std/compress:gzip(data: "")
| error e |> std/io:print.ln("ERR {{ e:s }}")
| compressed { data, original_size } |> std/compress:crc32(data): crc
    |> std/io:print.ln("empty {{ original_size:d }}->{{ data.len:d }} crc={{ crc:d }}")

// short literal — fixed block
std/compress:gzip(data: "hello koru")
| error e |> std/io:print.ln("ERR {{ e:s }}")
| compressed { data, original_size } |> std/compress:crc32(data): crc
    |> std/io:print.ln("short {{ original_size:d }}->{{ data.len:d }} crc={{ crc:d }}")

// repeated-key JSON — the shape that earns a dynamic Huffman block
std/compress:gzip(data: "{\"items\":[{\"id\":1,\"name\":\"item-1\",\"qty\":7},{\"id\":2,\"name\":\"item-2\",\"qty\":14},{\"id\":3,\"name\":\"item-3\",\"qty\":21}],\"count\":3}")
| error e |> std/io:print.ln("ERR {{ e:s }}")
| compressed { data, original_size } |> std/compress:crc32(data): crc
    |> std/io:print.ln("json {{ original_size:d }}->{{ data.len:d }} crc={{ crc:d }}")
