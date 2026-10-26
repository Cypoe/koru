// std/diag/jsonl — importing the module IS the subscription: its lone
// `std/compiler(diagnostic)` join registers a jsonl consumer for every
// diagnostic the backend reports. The pin is the artifact, not the refusal.
import std/diag/jsonl

totally-bogus()
