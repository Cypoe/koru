// The override module: qualifies the abstract's module from a DIFFERENT
// module — the cross-module override, living module-resident (430_014's
// shape, applied to a user-library runtime abstract instead of the
// coordinator).

import app/lib/greet

app/lib/greet:greet => greeted "overridden"
