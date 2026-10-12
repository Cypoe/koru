// PINS the C lane `const` template: `//@koru:file_scope` hoists the rendered
// `static const` declarations out of the flow fn to module scope — C gives
// each flow its own fn, so a decl inside one would be invisible to sibling
// flows (the zig lane survives fn-level const because every flow shares
// mains scope).
import std/io

const { x: 10, y: 20 }

std/io:print.ln("{{ x + y:d }}")
