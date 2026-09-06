// PIN (part): parts are flat — file-splitting only, no nesting. A `part`
// inside a part file must be refused with a teaching diagnostic: parts are
// not a second module system, and the promotion path for a part that
// outgrows its file is the directory module tree that already exists.
//
// ASPIRATIONAL: `part` is not implemented yet; this test fails until it is.

part a
