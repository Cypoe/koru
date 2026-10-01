// A `#L` fold where EVERY terminal arm ends in `@L` can never exit — the
// handler is re-dispatched forever — so it is refused with KORU206.
//
// This is the shape an external fuzzer hit: it meant `| done` to end the
// loop but put `@L` after `|>`, so `done` re-dispatched the head forever.
// `@L` means "jump back" on every arm — a terminal-sounding branch name
// does not change that. The exit spellings are `->` produce and a `|>`
// continuation (or arm end), never `@L`.
//
// The positive sibling is 247_label_fold_redispatch_exit_contract, and a
// legitimate loop-with-exit nested-fold shape is 208_simple_server_flow.

pub tor spin { n: i64 }
| again i64
| done i64

pub tor run { }

spin = if(n > 0)
| then => again n
| else => done n

run = #L spin(n: 3)
| again a |> @L(n: a - 1)
| done d |> @L(n: d)

run()
