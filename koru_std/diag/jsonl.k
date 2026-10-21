// std/diag/jsonl — diagnostics-bus consumer: every diagnostic the backend
// reports also lands here as one JSON object per line. The whole module is
// the join; importing it is the subscription.
import std/compiler

std/compiler(diagnostic)
! diagnostic d |> jsonl(d, path: "koru-diagnostics.jsonl")
