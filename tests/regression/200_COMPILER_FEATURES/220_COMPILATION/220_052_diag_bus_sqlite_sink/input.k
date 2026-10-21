// koru/diag/sqlite — the sqlite diagnostic sink lives in koru-libs, not
// stdlib: importing the module IS the subscription AND the dep. Its
// std/compiler:requires links libsqlite3 into the backend build and its
// `std/compiler(diagnostic)` join registers the consumer — a compiler plugin
// shipped as an ordinary package import. The pin is the .db row.
import koru/diag/sqlite

totally-bogus()
