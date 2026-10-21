// koru/compiler/sqlite — the sqlite diagnostic sink lives in koru-libs'
// compiler toolkit, not stdlib: importing the module IS the subscription AND
// the dep. Its std/compiler:requires links libsqlite3 into the backend build
// and its `std/compiler(diagnostic)` join registers the consumer — a
// compiler plugin shipped as an ordinary package import. The pin is the row.
import koru/compiler/sqlite

totally-bogus()
