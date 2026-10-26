// MIRROR of the `std/node(node)` bare-borrow form — the node:default
// transform — with the call site in an imported module.
//
// default rewrites `std/node(name)` into a node-self borrow; relocated into
// a module, the `| node f` arm's custody and the member-miss `not-found`
// arm must resolve identically.
import app/lib

app/lib:run()
