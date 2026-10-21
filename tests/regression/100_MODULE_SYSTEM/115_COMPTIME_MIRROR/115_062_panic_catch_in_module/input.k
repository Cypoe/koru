// MIRROR of 681_001_catch_answers_unhandled: `std/panic:catch` relocated
// into an imported module.
//
// catch is the one non-keyword transform in this batch — a site-pattern
// graft over an expression. Mirroring it checks the graft resolves a flow
// declared in the same module, not just the entry file.
import app/lib

app/lib:run()
