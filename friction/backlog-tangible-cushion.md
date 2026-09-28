# Koru friction backlog — classified

Session tangible-cushion: 140 diagnostics. BUG=28 DIAG=52 DESIGN=55 ENV=2 UNTAGGED=3

## BUG — 28 diagnostics

### PARSE003 ×13 — invalid branch name '|' - must be a valid identifier
- |> continuation misparsed as branch; message names token not rule
- exemplar: `tests/input.k:66` `|| err e3 |> std/io:print.ln("ogun init failed: {{ e3:s }}")`
- session response: The top-level bare `insert` isn't registering like a tor-driven fill. Matching the proven pattern — insert via a tor invoked in the chain:

### PARSE003 ×8 — unbalanced parentheses in invocation arguments
- mostly bisection-probe artifacts; real cause = continuation grammar
- exemplar: `main.k:164` `|> libs/ogun:mesh.vertc(eng,`
- session response: The `! each i` arm needs the `|>` on the same line. Fixing:

### PARSE001 ×7 — Source block missing closing brace
- symptom-diagnosis: 'missing closing brace' is really the first-field-on-{ line rule
- exemplar: `main.k:326` `|> std/store:insert(world) {`
- session response: Checking whether insert blocks can span lines at all:

## DIAG — 52 diagnostics

### KORU010 ×13 — stray continuation line without Koru construct
- 'stray continuation' covers >=3 distinct causes; fires on ! query arms too
- exemplar: `probe_wt.k:40` `|> std/io:print.ln("occ {{ w.cx:d }},{{ w.cy:d }} = {{ w.occ:d }}")`
- session response: That ran the stale mesh binary. Checking whether probe_wt.k actually compiled:

### KORU161 ×8 — std/store:query(phase): unknown plural store - no std/store:new(phase,
- names the mechanic, not what the name IS or which spelling to use instead
- exemplar: `tests/input.k:19` ``
- session response: Isolating — minimal repro of `query` inside a `tor` in a `.k` file:

### KORU161 ×6 — std/store:query(st): unknown plural store - no std/store:new(st, capac
- names the mechanic, not what the name IS or which spelling to use instead
- exemplar: `tests/input.k:19` ``
- session response: Isolating — minimal repro of `query` inside a `tor` in a `.k` file:

### KORU161 ×4 — std/store:query(tick): unknown plural store - no std/store:new(tick, c
- names the mechanic, not what the name IS or which spelling to use instead
- exemplar: `tests/input.k:19` ``
- session response: `tick` is likely a reserved word (ponkatris uses it as a tor name). Renaming the store:

### KORU030 ×2 — Phantom state mismatch: argument 'f' has no tracked
- phantom-state jargon; message truncated in log
- exemplar: `:` ``
- session response: The raylib package shows the exact shape: `std/build:requires` for linking, `@cImport` for the header, grid + `for` loop for per-entity draw

### KORU022 ×1 — branch 'frame' must be handled but no effect handler found
- points at the arm site, never explains which construct wants the branch
- exemplar: `basic.k:36` `|> libs/kodot:frames(eng: e, count: 240)`
- session response: The `|>` continuations need to nest deeper than the `| done` arm:

### KORU022 ×1 — branch 'done' must be handled but no continuation found
- points at the arm site, never explains which construct wants the branch
- exemplar: `basic.k:36` `|> libs/kodot:frames(eng: e, count: 240)`
- session response: The `|>` continuations need to nest deeper than the `| done` arm:

### KORU021 ×1 — event 'std.io:print.impl' has no branch 'frame' (available: (none))
- leaks impl-module internals into a user-facing error
- exemplar: `basic.k:37` `! frame f |> std/store:stripe(fleet) |> std/store:query(fleet)`
- session response: The `|>` continuations need to nest deeper than the `| done` arm:

### KORU021 ×1 — event 'std.io:print.impl' has no branch 'done' (available: (none))
- leaks impl-module internals into a user-facing error
- exemplar: `basic.k:39` `| done e2 |> libs/kodot:probe.pixel(eng: e2, x: 400, y: 300): px`
- session response: The `|>` continuations need to nest deeper than the `| done` arm:

### PARSE006 ×1 — bare argument 't0' does not name a parameter of 'report' — an explicit
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `bench.k:30` `| done e2 |> std/time:report(t0, "300 frames / 100000 entities")`
- session response: `for` point-free-claims the `done` name across the whole flow — colliding with `frames`' `| done`. Handling `for`'s done explicitly should d

### PARSE006 ×1 — bare argument '"300 frames / 100000 entities"' does not name a paramet
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `bench.k:30` `| done e2 |> std/time:report(t0, "300 frames / 100000 entities")`
- session response: `for` point-free-claims the `done` name across the whole flow — colliding with `frames`' `| done`. Handling `for`'s done explicitly should d

### PARSE006 ×1 — bare argument '4' does not name a parameter of 'spawn-hive' — an expli
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:344` `spawn-hives = spawn-hive(4, 6, 0) |> spawn-hive(8, 5, 1) |> spawn-hive(12, 6, 2)`
- session response: Koru requires labeled arguments everywhere. Fixing all bare-arg calls:

### PARSE006 ×1 — bare argument '6' does not name a parameter of 'spawn-hive' — an expli
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:344` `spawn-hives = spawn-hive(4, 6, 0) |> spawn-hive(8, 5, 1) |> spawn-hive(12, 6, 2)`
- session response: Koru requires labeled arguments everywhere. Fixing all bare-arg calls:

### PARSE006 ×1 — bare argument '0' does not name a parameter of 'spawn-hive' — an expli
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:344` `spawn-hives = spawn-hive(4, 6, 0) |> spawn-hive(8, 5, 1) |> spawn-hive(12, 6, 2)`
- session response: Koru requires labeled arguments everywhere. Fixing all bare-arg calls:

### PARSE006 ×1 — bare argument '8' does not name a parameter of 'spawn-hive' — an expli
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:344` `spawn-hives = spawn-hive(4, 6, 0) |> spawn-hive(8, 5, 1) |> spawn-hive(12, 6, 2)`
- session response: Koru requires labeled arguments everywhere. Fixing all bare-arg calls:

### PARSE006 ×1 — bare argument '5' does not name a parameter of 'spawn-hive' — an expli
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:344` `spawn-hives = spawn-hive(4, 6, 0) |> spawn-hive(8, 5, 1) |> spawn-hive(12, 6, 2)`
- session response: Koru requires labeled arguments everywhere. Fixing all bare-arg calls:

### PARSE006 ×1 — bare argument '1' does not name a parameter of 'spawn-hive' — an expli
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:344` `spawn-hives = spawn-hive(4, 6, 0) |> spawn-hive(8, 5, 1) |> spawn-hive(12, 6, 2)`
- session response: Koru requires labeled arguments everywhere. Fixing all bare-arg calls:

### PARSE006 ×1 — bare argument '12' does not name a parameter of 'spawn-hive' — an expl
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:344` `spawn-hives = spawn-hive(4, 6, 0) |> spawn-hive(8, 5, 1) |> spawn-hive(12, 6, 2)`
- session response: Koru requires labeled arguments everywhere. Fixing all bare-arg calls:

### PARSE006 ×1 — bare argument '2' does not name a parameter of 'spawn-hive' — an expli
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:344` `spawn-hives = spawn-hive(4, 6, 0) |> spawn-hive(8, 5, 1) |> spawn-hive(12, 6, 2)`
- session response: Koru requires labeled arguments everywhere. Fixing all bare-arg calls:

### PARSE006 ×1 — bare argument 'w.weapon' does not name a parameter of 'wcol-r' — an ex
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:436` `! query w when w.kind == K_CRATE or w.kind == K_POW`
- session response: A comment inside the chain breaks it — moving it above the flow:

### PARSE006 ×1 — bare argument 'w.weapon' does not name a parameter of 'wcol-g' — an ex
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:438` `|> wcol-g(w.weapon): cg`
- session response: A comment inside the chain breaks it — moving it above the flow:

### PARSE006 ×1 — bare argument 'w.weapon' does not name a parameter of 'wcol-b' — an ex
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:439` `|> wcol-b(w.weapon): cb`
- session response: A comment inside the chain breaks it — moving it above the flow:

### PARSE006 ×1 — bare argument 'mm_crate' does not name a parameter of 'mm-of' — an exp
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:440` `|> mm-of(w, mm_crate, mm_pow): m`
- session response: A comment inside the chain breaks it — moving it above the flow:

### PARSE006 ×1 — bare argument 'mm_pow' does not name a parameter of 'mm-of' — an expli
- rule is fine but hint fabricates non-param labels ('w: mm_crate'); also 9x spam per line
- exemplar: `main.k:440` `|> mm-of(w, mm_crate, mm_pow): m`
- session response: A comment inside the chain breaks it — moving it above the flow:

## DESIGN — 55 diagnostics

### KORU104 ×8 — nested call in argument 'x' — calls are not expressions; use tor chain
- calls-not-expressions forces capture-binding ceremony (lowering detail as user rule)
- exemplar: `main.k:415` `! query w when w.kind == K_HEAD`
- session response: Calls can't nest in arguments — each needs a `tor(): capture` binding first. Rewriting `paint-world` with bound captures:

### KORU104 ×8 — nested call in argument 'z' — calls are not expressions; use tor chain
- calls-not-expressions forces capture-binding ceremony (lowering detail as user rule)
- exemplar: `main.k:415` `! query w when w.kind == K_HEAD`
- session response: Calls can't nest in arguments — each needs a `tor(): capture` binding first. Rewriting `paint-world` with bound captures:

### KORU031 ×3 — `| done` handled here, but has wrong type: 'frames' carries *Engine, c
- point-free choke name collisions across stages ('done' is a global name)
- exemplar: `bench.k:30` `| done e2 |> std/time:report(start: t0, label: "300 frames / 100000 entities")`
- session response: `for` point-free-claims the `done` name across the whole flow — colliding with `frames`' `| done`. Handling `for`'s done explicitly should d

### KORU115 ×3 — host type 'Frame' crosses a module boundary bare — write it qualified:
- host-type qualification at module boundary — good message, debatable rule
- exemplar: `tests/input.k:14` `// frame 0: push LEFT-press. Dispatched during ogun_frame -> queue.`
- session response: The top-level bare `insert` isn't registering like a tor-driven fill. Matching the proven pattern — insert via a tor invoked in the chain:

### PARSE005 ×2 — redundant explicit label 'y:' — the value 'y' already puns to 'y'
- pun-mandatory: label-forbidden direction of the seesaw
- exemplar: `mesh.k:24` `nx: @cos(a), ny: 0.0, nz: @sin(a))`
- session response: Mandatory punning — `y: y` → `y`:

### KORU104 ×2 — nested call in argument 'r' — calls are not expressions; use tor chain
- calls-not-expressions forces capture-binding ceremony (lowering detail as user rule)
- exemplar: `main.k:435` `|> libs/ogun:multimesh.tint(f, mm: mm_crate, id: w.slot, r: wcol-r(w.weapon), g:`
- session response: Calls can't nest in arguments — each needs a `tor(): capture` binding first. Rewriting `paint-world` with bound captures:

### KORU104 ×2 — nested call in argument 'g' — calls are not expressions; use tor chain
- calls-not-expressions forces capture-binding ceremony (lowering detail as user rule)
- exemplar: `main.k:435` `|> libs/ogun:multimesh.tint(f, mm: mm_crate, id: w.slot, r: wcol-r(w.weapon), g:`
- session response: Calls can't nest in arguments — each needs a `tor(): capture` binding first. Rewriting `paint-world` with bound captures:

### KORU104 ×2 — nested call in argument 'b' — calls are not expressions; use tor chain
- calls-not-expressions forces capture-binding ceremony (lowering detail as user rule)
- exemplar: `main.k:435` `|> libs/ogun:multimesh.tint(f, mm: mm_crate, id: w.slot, r: wcol-r(w.weapon), g:`
- session response: Calls can't nest in arguments — each needs a `tor(): capture` binding first. Rewriting `paint-world` with bound captures:

### SHAPE002 ×2 — multiple unnamed '|>' steps at the same level — consecutive '|>' lines
- one multi-line invocation per chain — line-oriented grammar
- exemplar: `main.k:519` `|> libs/ogun:mesh.begin(eng)`
- session response: Calls can't nest in arguments — each needs a `tor(): capture` binding first. Rewriting `paint-world` with bound captures:

### KORU161 ×2 — std/store:insert(world): punning is mandatory — drop the redundant lab
- same seesaw, store side
- exemplar: `main.k:338` `spawn-hive = wx(cx): x |> wz(cy): z`
- session response: Same comment-inside-block bug in the store schemas. Cleaning them:

### KORU161 ×2 — std/store:query(world): exactly one `! query <row>` or `! first <row>`
- one-arm-per-site forces query splits + nested-if dispatch
- exemplar: `main.k:421` `paint-world = std/store:query(world)`
- session response: Same comment-inside-block bug in the store schemas. Cleaning them:

### KORU161 ×2 — std/store:query(fx): 'e.slot' - 'slot' is not a field of store 'fx'
- schema field discipline — legit but strict
- exemplar: `main.k:447` `paint-fx = std/store:query(fx)`
- session response: Same comment-inside-block bug in the store schemas. Cleaning them:

### PARSE005 ×1 — redundant explicit label 'id:' — the value 's.id' already puns to 'id'
- pun-mandatory: label-forbidden direction of the seesaw
- exemplar: `basic.k:30` `! query s |> libs/kodot:item.move(f, id: s.id, x: @as(f32, @floatFromInt(s.x)), `
- session response: Punning rule — drop the label:

### KORU100 ×1 — unused binding 'sc'
- unused binding wall — fine
- exemplar: `bench.k:30` `| eng e`
- session response: **First number: 300 frames / 100k entities = 9219ms → ~30.7ms/frame (~307ns per entity-frame, all-in: store sweep + rule write + direct `Ins

### PARSE005 ×1 — redundant explicit label 'eng:' — the value 'eng' already puns to 'eng
- pun-mandatory: label-forbidden direction of the seesaw
- exemplar: `:` ``
- session response: Two fixes: `_` for the discard binding, and `@divTrunc` for signed division:

### PARSE005 ×1 — redundant explicit label 'mm:' — the value 'mm' already puns to 'mm'
- pun-mandatory: label-forbidden direction of the seesaw
- exemplar: `:` ``
- session response: Two fixes: `_` for the discard binding, and `@divTrunc` for signed division:

### KORU161 ×1 — std/store:query(fleet): exactly one `! query <row>` or `! first <row>`
- one-arm-per-site forces query splits + nested-if dispatch
- exemplar: `:` ``
- session response: The trailing `commit` broke the query's single-arm rule. Need to check how `frames` orders the arm body vs the `kodot_frame` call before pla

### PARSE005 ×1 — redundant explicit label 'f:' — the value 'f' already puns to 'f'
- pun-mandatory: label-forbidden direction of the seesaw
- exemplar: `tests/input.k:61` `|> phase-order(f: f)`
- session response: The top-level bare `insert` isn't registering like a tor-driven fill. Matching the proven pattern — insert via a tor invoked in the chain:

### PARSE005 ×1 — redundant explicit label 'clip:' — the value 's.clip' already puns to 
- pun-mandatory: label-forbidden direction of the seesaw
- exemplar: `audio.k:45` `}`
- session response: Query arms don't nest mid-chain there — moving the clip-id store into its own tor, matching the established pattern:

### PARSE005 ×1 — redundant explicit label 'voice:' — the value 's.voice' already puns t
- pun-mandatory: label-forbidden direction of the seesaw
- exemplar: `audio.k:59` `|> libs/ogun:audio.stop(f, voice: s.voice)`
- session response: Query arms don't nest mid-chain there — moving the clip-id store into its own tor, matching the established pattern:

### PARSE004 ×1 — unmatched '{' in tor shape
- tor-shape brace rule — same grammar family
- exemplar: `:` ``
- session response: The parser hits EOF still inside an open paren — but Python counts them balanced. Something subtler. Bisecting inside `cyl`:

### KORU100 ×1 — unused binding 'i'
- unused binding wall — fine
- exemplar: `:` ``
- session response: Found the parser limit — **two multi-line invocations in one chain step fail**. Not worth a compiler detour mid-port; rewriting `cyl`/`spher

### KORU202 ×1 — tor 'wx' already declared — redeclared in this file
- redeclaration — fine
- exemplar: `main.k:319` ``
- session response: Already declared at line 291 — dropping my duplicates:

### PARSE005 ×1 — redundant explicit label 'yaw:' — the value 'w.yaw' already puns to 'y
- pun-mandatory: label-forbidden direction of the seesaw
- exemplar: `main.k:417` `|> libs/ogun:multimesh.tint(f, mm: mm_head, id: w.slot, r: 0.85, g: 1.0, b: 0.95`
- session response: Koru puns `w.yaw` to `yaw` automatically — dropping the redundant labels:

### PARSE005 ×1 — redundant explicit label 'x:' — the value 'e.x' already puns to 'x'
- pun-mandatory: label-forbidden direction of the seesaw
- exemplar: `main.k:446` `sx: e.sx, sy: e.sy, sz: e.sz)`
- session response: A `for` with an arm body can't be a mid-chain step — same stranded-continuation rule as `if`. Extracting the event drain into its own tor:

### PARSE005 ×1 — redundant explicit label 'cx:' — the value 'w.cx' already puns to 'cx'
- pun-mandatory: label-forbidden direction of the seesaw
- exemplar: `main.k:421` `|> libs/ogun:multimesh.tint(f, mm, id: w.slot, r, g, b, a: 1.0)`
- session response: A comment inside the chain breaks it — moving it above the flow:

### KORU176 ×1 — field has no name — a field is `name: value` or a bare punnable name; 
- field naming discipline — fine
- exemplar: `main.k:21` ``
- session response: Frontend passes — now a backend error at line 21, inside the `const {}` block:

### KORU161 ×1 — std/store:query(game): exactly one `! query <row>` or `! first <row>` 
- one-arm-per-site forces query splits + nested-if dispatch
- exemplar: `main.k:462` `hud = std/store:query(game)`
- session response: Four backend rules surfaced: one `! query` arm per query site, mandatory puns in insert blocks, and `fx` needs a `slot` field. Restructuring

### PARSE005 ×1 — redundant explicit label 'kind:' — the value 'w.kind' already puns to 
- pun-mandatory: label-forbidden direction of the seesaw
- exemplar: `main.k:453` `! query w |> paint-one(f, kind: w.kind, weapon: w.weapon, slot: w.slot, cx: w.cx`
- session response: Six emitted-Zig errors. Checking each site:

## ENV — 2 diagnostics

### E0432 ×2 — unresolved import `bevy::render::view::VisibilitySystems`
- bevy/rust phase of session, not koru
- exemplar: `src/main.rs:8` `use bevy::render::view::VisibilitySystems;`
- session response: 0.17 moved visibility to `bevy_camera`. Checking the set name there:

## UNTAGGED — 3 diagnostics

### PARSE003 ×2 — unknown import alias: 'libs'
- 
- exemplar: `/tmp/aprobe.k:1` `import libs/ogun`
- session response: Reproduced — a mid-chain tor call with named args trips it. Testing whether bare-parens vs. labeled args is the trigger:

### PARSE003 ×1 — impl name ' string' is not one a call site can spell — each '.'-separa
- 
- exemplar: `main.k:275` `const FLOOR_SHADER: string = "shader_type spatial;\nrender_mode unshaded;\nunifo`
- session response: Two issues: the `|> bake` after a nested `if` can't reattach, and my `const NAME: string =` syntax is wrong. Checking how string constants a


## TEACH-MISS — diagnostics that produced a guess instead of a rule

| code | diagnostic | the agent concluded | could have taught |
|---|---|---|---|
| PARSE005 | redundant explicit label 'f:' — the value 'f' already puns t | The top-level bare `insert` isn't registering like a tor-driven fill. Matching the proven  | state the full seesaw rule once: label required UNLESS the value puns — both directions |
| PARSE003 | invalid branch name '\|' - must be a valid identifier | The top-level bare `insert` isn't registering like a tor-driven fill. Matching the proven  | name the context rule violated, not the token ('a |> continuation cannot follow X') |
| KORU115 | host type 'Frame' crosses a module boundary bare — write it  | The top-level bare `insert` isn't registering like a tor-driven fill. Matching the proven  | — |
| KORU161 | std/store:query(tick): unknown plural store - no std/store:n | `tick` is likely a reserved word (ponkatris uses it as a tor name). Renaming the store: | name what the identifier IS (singleton store? scalar? undeclared?) + the right spelling: `std/store(name) ! field` for a standing watch, `query` for a plural |
| KORU161 | std/store:query(phase): unknown plural store - no std/store: | Isolating — minimal repro of `query` inside a `tor` in a `.k` file: | name what the identifier IS (singleton store? scalar? undeclared?) + the right spelling: `std/store(name) ! field` for a standing watch, `query` for a plural |
| KORU161 | std/store:query(st): unknown plural store - no std/store:new | storeprobe2 got past store resolution — the difference might literally be `capacity: 1`. T | name what the identifier IS (singleton store? scalar? undeclared?) + the right spelling: `std/store(name) ! field` for a standing watch, `query` for a plural |
| KORU010 | stray continuation line without Koru construct | That ran the stale mesh binary. Checking whether probe_wt.k actually compiled: | name why the previous line can't take a continuation (arm body / consumed chain / comment between) |
| PARSE001 | Source block missing closing brace | Checking whether insert blocks can span lines at all: | the real rule: a source block's first field must sit on the `{` line |
