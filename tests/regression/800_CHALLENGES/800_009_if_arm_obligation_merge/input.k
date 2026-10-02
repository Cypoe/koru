import std/io
import std/store
import app/lib/post
import app/lib/stamps

// MINIMAL REPRO: an obligation consumed by BOTH arms of an if inside a
// for-body, followed by a |> continuation, is still seen as live at the
// merge — KORU030 says <held!> was never discharged.
//
// Expected: both arms consume p (sign/stamp-express take <!held>), so the
// merge has nothing to discharge — the program should compile and run.
// Actual:   error[KORU030]: Resource 'p' obligation <held!> was not
//           discharged, blamed on the |> line after the if.

std/store:new(board) { n: 0[i64] }

tor go {}
go = for(0..@as(usize, 2))
    ! each i |> app/lib/post:took-pouch(seal: @as(i64, @intCast(i))): p
        |> if(@mod(@as(i64, @intCast(i)), 2) == 0)
            | then |> app/lib/stamps:sign(p): p1
                |> app/lib/stamps:wax(p: p1): p2
                |> app/lib/stamps:carry(p: p2): p3
                |> app/lib/stamps:arrive(p: p3): p4
                |> app/lib/post:file-dispatch(p: p4)
            | else |> app/lib/stamps:stamp-express(p): p1
                |> app/lib/stamps:arrive(p: p1): p2
                |> app/lib/post:file-dispatch(p: p2)
        |> std/store:stored { board.n: board.n + 1 }

go()
|> std/io:print.ln("done")
