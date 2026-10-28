---
type: belief
id: frag-a-kmd-hosts-bytes-are-data
provenance: .kmd document host landing 2026-10-28 — the ruling itself is docs/KMD.md (2026-10-25); this fragment records the belief the family tree had to give up
ts: 2026-10-28
---

# A `.kmd` host's bytes are data — the document is the comptime residue

The `.k<host>` family's invariant until now: a host line is *code for a
backend* — text routed to one target's emitter ([[frag-a-kjs-facet-carries-host-lines-not-only-proc-bodies]],
`hostLineRoutesToZig`). `.kmd` breaks that invariant deliberately. Its
hostlines are Markdown — document text, data — and there is no backend at
all. The file is stamped implicitly `~[comptime]` by the parser; the
compile *evaluates* the file and what remains unevaluated, in file order,
is the emitted `.md` artifact.

Two consequences follow, and both are load-bearing rather than incidental:

**Residue is a compile failure, never muted output.** A `~` construct the
comptime stage cannot consume (a runtime call, a non-`~const` invocation)
does not get silently dropped from the document — it is a compile error
with a teaching hint, the same wall shape as KORU141. A document host that
swallowed unconsumed constructs would emit a file that lies about what the
program did. v1's honest edge is `~const` bindings feeding Liquid `{{ }}`
substitution; comptime-result splicing is the named open rung, refused
rather than approximated.

**Document grammar owns every line Koru doesn't.** The only sigil is `~`
at column 0 (second char not `~`/space/tab — `~~` is strikethrough, `~~~`
a tilde-fence). A CommonMark fenced block makes every line inside it
document text, sigils included — the one bit of parser state the
classification needs. `|`/`!` are structural only inside a construct's own
extent, so tables and prose at top level are data. Indented code is data
automatically, because the sigil rule is column-0.

The sibling-companion rule is worth naming too: a same-stem `.kz` is still
a companion of a `.kmd` and merges into the parse — the document host
inherits the module-merge machinery unchanged.
