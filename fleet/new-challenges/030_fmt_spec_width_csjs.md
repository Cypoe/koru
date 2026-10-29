---
challenge: fmt-spec-width-csjs
kind: frame
status: standing
yields: `d:N` width spec implemented (or loudly refused) on the CS and JS emission targets, with a cross-target pin
family: emitter
created: 2026-10-29
---

Found during `029_the_host_leak_audit` (same measured sweep, tree
Cypoe/challenge-029-the-host-leak-audit + d:N hoist commit).

The `d:N` ruling (2026-10-24, Koru owns the width semantic) landed on the
Zig target as `{f}` + `__koru_pad_i(N, arg)`. The sibling targets were
measured this session to do something worse than wrong: they DROP the
width silently.

- `koru_std/fmt.csprec.kz` `csHole` — `{{ v:d:8 }}` falls through to
  `__koru_str(v)`: the `d:8` spec is parsed but only `S`, `d`, `f`, and
  `:.N` precision get handling; `d:N` renders unpadded.
- `koru_std/fmt.jsprec.kz` `jsPlaceholder` — only `:.N` precision is
  handled (`toFixed(N)`); `d:N` emits the bare variable.
- Same shape on Zig pre-hoist: `io.kz`/`fmt.lnzig.kz`/`fmt.kz`/`io.blk.kz`
  passed `d:8` verbatim into Zig's `{d:8}` → `+   14683` (now Koru-owned).

Yield: `{{ v:d:N }}` on C# → `{(v),N}` alignment (pads to N, right-aligned,
sign only when negative — matches the ruled semantic); on JS →
`String(v).padStart(N)`. Or refuse `d:N` loudly until implemented —
a refused spec is honest, a dropped one is not. Verify with
`--cross-targets`; could not be run on the WSL host where measured.

Adjacent unmeasured site: `d:.N` (precision) still passes verbatim into
Zig's `{d:.N}` — same verbatim-passthrough shape, separate exhibit for
the audit frame.
