// The head-bound shape from 320_097: `clock(passes): n` binds the
// proc's return to `n`, used by the arm record and the nested if's
// guard. `clock` is a single-return |zig proc — extraction reads
// `return passes;` and conditions the certificate on that body
// literally being the function. F: passes -> passes + 1, guard
// passes < limit.
tor clock { passes: i64 } -> i64

proc clock|zig {
    return passes;
}

tor tick { limit: i64, passes: i64 }
| live { limit: i64, passes: i64 }
| expired i64

tick = clock(passes): n |> if(n < limit)
    | then => live { limit, passes: n + 1 }
    | else => expired n

run = #L tick(limit, passes: 0)
| live l |> @L(l.limit, l.passes)
| expired e -> e

run(limit: 6): n |> _
