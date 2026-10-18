// PINS: the thread's ambiguity refusal cannot be dissolved by a scope
// binding. 210_180 pins `merge`-shaped callees — two unfilled same-type
// params — as KORU093 with an empty scope. The same program WITH a compatible
// binding in scope must still refuse: the fill pass may complete calls, but
// it may not preempt the thread's candidacy — `o` answering `a` and `b` here
// would silently discard the produce AND hide the election the author needed
// to make. Both slots belong to the thread's election first.
import std/io

tor other {} -> string
proc other|zig { return "other"; }

tor produce {} -> string
proc produce|zig { return "made"; }

tor consume { a: string, b: string }
proc consume|zig { }

other(): o |> produce() |> consume()
