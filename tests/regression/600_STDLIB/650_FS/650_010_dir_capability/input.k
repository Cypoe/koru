// PIN: fs:dir mints a directory capability confined to its root — the
// sandbox IS the handle. list/read/write/read-lines-in/collect-lines take
// *Dir<open>; `..` components and absolute paths fire | failed inside
// std/fs, not at the call site; close discharges *Dir<!open>.
// collect-lines materializes the ! line stream as a []string field —
// the shape a wire consumer sees, since wire arms cannot spell `!`.
import std/io
import std/fs

tor step-fence3 { d: *std/fs:Dir<open> }
step-fence3 = std/fs:read(d, path: "missing.txt")
| text t |> std/io:print.ln("FAIL missing {{ t:s }}")
| failed e |> std/io:print.ln("missing {{ e:s }}")

tor step-fence2 { d: *std/fs:Dir<open> }
step-fence2 = std/fs:read(d, path: "/etc/passwd")
| text t |> std/io:print.ln("FAIL abs {{ t:s }}")
| failed e |> std/io:print.ln("fenced-abs {{ e:s }}") |> step-fence3(d)

tor step-fence { d: *std/fs:Dir<open> }
step-fence = std/fs:read(d, path: "../escape")
| text t |> std/io:print.ln("FAIL escape {{ t:s }}")
| failed e |> std/io:print.ln("fenced-rel {{ e:s }}") |> step-fence2(d)

tor step-pulse { d: *std/fs:Dir<open> }
step-pulse = std/fs:read-lines-in(d, path: "input.txt")
! line l |> std/io:print.ln("pulse {{ l:s }}")
| done n |> std/io:print.ln("-- pulsed {{ n:d }}") |> step-fence(d)
| failed e |> std/io:print.ln("FAIL pulse {{ e:s }}")

tor step-collect { d: *std/fs:Dir<open> }
step-collect = std/fs:collect-lines(d, path: "input.txt")
| lines ls |> for(0..ls.len)
    ! each i |> std/io:print.ln("line {{ ls[i]:s }}")
    | done |> std/io:print.ln("-- collected") |> step-pulse(d)
| failed e |> std/io:print.ln("FAIL collect {{ e:s }}")

tor step-write { d: *std/fs:Dir<open> }
step-write = std/fs:write(d, path: "hello.txt", content: "hello world\n")
| written |> std/io:print.ln("wrote") |> step-collect(d)
| failed e |> std/io:print.ln("FAIL write {{ e:s }}")

tor step-read { d: *std/fs:Dir<open> }
step-read = std/fs:read(d, path: "hello.txt")
| text t |> std/io:print.ln("text: {{ t:s }}") |> step-write(d)
| failed e |> std/io:print.ln("FAIL read {{ e:s }}")

tor probe { d: *std/fs:Dir<open> }
probe = std/fs:list(d)
| entries xs |> for(0..xs.len)
    ! each i |> std/io:print.ln("entry {{ xs[i]:s }}")
    | done |> std/io:print.ln("-- listed") |> step-read(d)
| failed e |> std/io:print.ln("FAIL list {{ e:s }}")

std/fs:dir(path: "tests/regression/600_STDLIB/650_FS/650_010_dir_capability/sandbox")
| opened d |> probe(d) |> std/fs:close(d) |> std/io:print.ln("closed")
| failed e |> std/io:print.ln("FAIL dir {{ e:s }}")
