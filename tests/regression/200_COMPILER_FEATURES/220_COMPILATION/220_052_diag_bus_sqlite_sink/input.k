// koru/compiler/sqlite — the sqlite diagnostic sink lives in koru-libs'
// compiler toolkit, not stdlib: importing the module IS the subscription AND
// the dep. Its std/compiler:requires links libsqlite3 into the backend build
// and its `std/compiler(diagnostic)` join registers the consumer — a
// compiler plugin shipped as an ordinary package import. Sink settings are a
// module-targeted `X:config` directive (same family as compiler:use, x:new) —
// the custom db-file below proves config crosses the barrier. The pin is the
// row in the configured file.
import koru/compiler/sqlite

koru/compiler/sqlite:config {
    db-file: "custom-diag.db"
    flush: true
}

totally-bogus()
