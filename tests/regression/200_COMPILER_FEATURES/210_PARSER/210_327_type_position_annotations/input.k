// PIN: compiler annotations on type positions — `Type[ann]` extracts into
// `type_annotations` (opaque, any content, comma list) and is STRIPPED
// before Zig emission. `Type<a,b>` → two annotations; `Type<ph>[ann]`
// stacks phantom-inner/annotation-outermost. If any `[ann]` leaked through
// to the emitted Zig it would die as an array-index on a type.
import std/io

pub tor echo { v: i64[note, tagged] } -> i64
echo -> v

pub tor unit { }
| done i64[scalar]
| failed string

unit = if(true)
| then => done 7
| else => failed "no"

unit()
| done x |> echo(v: x): y |> std/io:print.ln("{{ y:d }}")
| failed m |> std/io:print.ln("fail {{ m:s }}")
