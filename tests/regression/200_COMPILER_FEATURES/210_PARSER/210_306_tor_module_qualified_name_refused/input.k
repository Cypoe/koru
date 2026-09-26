// PINS: a tor is declared in its own module. `m:speech` asks this file to
// declare a tor inside module `m` — the qualified spelling is the IMPL
// side's (`~proc m:name` implements a contract where it lives), never the
// declaration's.
import std/io

tor m:speech {}
