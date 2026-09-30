// Pins that a bound tree which cannot be read is refuse, not an unpinned
// default (130_005) and not a silent skip. The lock names the path; the path
// is absent. The diagnostic names the unread tree.

// Pins that a bound tree which cannot be read is refuse, not an unpinned
// default (130_005) and not a silent skip. The lock names the path; the path
// is absent. The diagnostic names the unread tree. Do not import the module —
// that would be KORU002 before the pin can speak.

import std/vendor

std/vendor:bindings {
    koru/vaxis: ./vendored/vaxis
}

tor main {}
main()
