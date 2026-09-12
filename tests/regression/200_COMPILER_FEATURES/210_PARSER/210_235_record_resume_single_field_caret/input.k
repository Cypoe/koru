// PINS: the caret names the line carrying the fault. This site was
// audited in challenge 023's parser sweep: it previously reported one
// line off the construct it describes (the parse cursor is a 0-based
// buffer index and the reporter expects a 1-based line; this site
// handed over the wrong adjustment).

import std/compiler


tor ask { x: i32 }
! askme i32 -> { a: i64 }
