// The `#L`/`@L` fold contract, pinned in both directions:
//
//   `@L` re-dispatches — on EVERY arm, including one named `done`. A
//   terminal-sounding branch name does not make an arm an exit; the jump
//   decides. Here `| done` jumps back once (reseed 90) before its `| else`
//   produces, proving the back-edge on a terminal-named arm is real.
//
//   `->` produce and a `|>` continuation (or arm end) exit the fold —
//   `| else -> d` produces 90 and the program prints it.
//
// Trace: tick(0..4) -> again; tick(5) -> done 5; done's arm re-dispatches
// once (@L(n: 90)); tick(90) -> done 90; 90 < 10 fails, so `-> d` exits with
// 90. Output: "90".
//
// The sibling negative is 246_label_fold_all_back_edges_refused: when EVERY
// arm jumps back, the fold cannot exit and is refused at compile time.

import std/io

tor tick { n: i64 }
| again i64
| done i64

tor run { start: i64 } -> i64

tick = if(n < 5)
| then => again n
| else => done n

run = #L tick(n: start)
| again a |> @L(n: a + 1)
| done d |> if(d < 10)
    | then |> @L(n: 90)
    | else -> d

run(start: 0): r |> std/io:print.ln("{{ r:d }}")
