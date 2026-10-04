// Pins: a call whose '(' does not hug its first argument is a parse
// refusal — 'adx( 7, ...' is C-style spacing, not Koru. The ')' edge is
// refused by the same rule.
import std/io

tor adx { qlen: i32, dx: i32 } -> i32
adx -> qlen + dx

use = adx( 7, dx: 3): m
    |> std/io:print.ln("{{ m:d }}")
