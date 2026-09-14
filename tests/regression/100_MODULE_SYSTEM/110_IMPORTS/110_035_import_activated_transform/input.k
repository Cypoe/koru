// Test: a transform tor carried inside an imported module fires because the
// import landed it in the program tree — the entry never writes the
// invocation. `koru_std/ccp.kz`'s top-level `~tap(* -> *)` is this shape in
// production; this pins it for an arbitrary user-defined transform, which is
// the mechanism ambient Source-block handling (std/refine-style) rides on.
//
// Structure:
//   test_lib/mymod.k  → defines `install` transform + a top-level
//                       `install(mymod)` invocation that fires at Stage C
//                       and self-dissolves.
//   input.k           → imports the module, then prints at runtime.
//
// Expected: Stage C output carries `mymod install fired` (expected_comptime);
//           runtime prints `entry ran` — the install flow left no residue.
import app/test_lib/mymod
import std/io

std/io:print.ln("entry ran")
