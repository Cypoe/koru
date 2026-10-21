# 620_014 — fmt:ln scoped param conferral (positive half)

The legal path 620_013/620_015 refuse around. A param spelled
`string<*@scoped>` declares two things at once: any identity is accepted
(the `*` wildcard) *and* the class is declared, so a `scratch@scoped`
borrow may cross the wall.

Inside the callee the binding carries the class — `sink` consumes `data`
in place with `print.ln`, which is legal because consumption never moves
the borrow out of its frame.

`passthru` pins the class-preserving reissue: its declared output
`-> string<*@scoped>` may hand a scoped value on, and the caller's
binding `d` stays scoped — a tor can forward a borrow without laundering
it, but only because the declaration says so at both ends.

Expected output: `item 1`, `more 2`, `more 2` — the borrow round-trips
through two declared-scoped params and is printed by the caller.
