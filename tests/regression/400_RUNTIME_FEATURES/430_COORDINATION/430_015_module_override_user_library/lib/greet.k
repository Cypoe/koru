// The library module: declares the abstract and its own default answer.
// The unqualified impl is THIS module's own implementation — the default —
// never an override (its home is the abstract's own module).

[abstract] pub tor greet { name: string }
| greeted string
| skipped

greet => greeted "default"
