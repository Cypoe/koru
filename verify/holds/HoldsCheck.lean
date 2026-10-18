/-
Holds ledger checker — the runtime custody record, re-decided.

The writer is `bridge.custody.kz`: a world-mounted bridge installs
`on_custody` on its `HandlePool`, and every mint (`acquire`) and release
(`dischargeById`/`discharge` — explicit verbs, the AUTO-DISCHARGE sweep,
and `close`'s hang-up `dischargeAll` all funnel through them) appends one
line to `<world>/holds.log`, bracketed by `session-open`/`session-closed`
marks. The pool enforces possession — `assertHandlesHeld` refuses a spend
or borrow naming nothing held — so the record is honest about what the
runtime DID. This checker decides whether the record is a lawful custody
ledger: enforcement is the source of truth, the log is evidence, and
evidence gets re-decided, not trusted (N1: solver ≠ checker).

Vocabulary — one event per line, tab-separated, fields in this order:

    session-open    t=<ms>  session=<id>
    session-closed  t=<ms>  session=<id>
    mint    t=<ms>  session=<id>  handle=<h>  verb=<creating-tor>  type=<T>  subject=<args>
    use     t=<ms>  session=<id>  handle=<h>  verb=<exercising-tor>
    release t=<ms>  session=<id>  handle=<h>  by=<discharge-tor>

Ledger rules, per session span:

    session-open      the id has no open span (a closed id may re-open —
                      process restart reusing an id is a new span)
    mint              span open; handle not already live (double-mint is
                      refused — `findByHandleId` could never name both)
    use               span open; handle live — a borrow only exercises,
                      it does not move custody (the writer emits it where
                      `assertHandlesHeld` admits the claim, so a `use`
                      line on a dead handle means enforcement regressed,
                      not that a borrow slipped through)
    release           span open; handle live (never-minted and
                      already-released are different named failures)
    session-closed    span open and EMPTY — `close` runs `dischargeAll`
                      before the mark, so live holds here mean the record
                      dropped releases, not that a program held them
    end of log        no span may remain open — `unclosed-session` (held
                      nothing) vs `died-holding` (names the live handles)
                      are both `malformed`, distinct codes: a faithful
                      record of an unsettled hold is still unsettled

Any other kind is out of vocabulary and refused. A dropped mint+release
PAIR is the known channel limit: balance cannot see what was never
written, exactly as the compile-time ledger cannot see an edge the
checker never walked.

Role A: `heldSpec` is an independent reference scan — the most recent
event touching `(s,h)` decides held-ness, span boundaries erase — and the
simulation theorem shows the ledger's `live` sets agree with it at every
accepted prefix. `heldSpec_true` extracts the pairing: held means a mint
with no intervening settle. `clean_sound` is the deliverable statement:
an empty violation list certifies that nothing remains held anywhere and
every release — and every use — was backed by a live mint at its
position.

Run (Role B):  lean --run HoldsCheck.lean <holds.log>   — verdict must be clean
-/

namespace Koru.HoldsCheck

/-! ## Events -/

inductive EvKind where
  | sessionOpen | sessionClosed | mint | use | release
deriving DecidableEq, Repr

/-- One parsed custody event. `handle` is set only on `mint`/`use`/`release`. -/
structure Ev where
  kind : EvKind
  session : String
  handle : String := ""
  line : Nat
deriving Repr, DecidableEq

def isNatTok (s : String) : Bool := !s.isEmpty && s.all Char.isDigit

/-- `tok` must spell `key=<v>` with a non-empty `v`. -/
def fieldVal (tok key : String) : Option String :=
  if tok.startsWith (key ++ "=") then
    let v := (tok.drop (key.length + 1)).toString
    if v.isEmpty then none else some v
  else none

def fieldTs (tok : String) : Option Unit :=
  match fieldVal tok "t" with
  | some v => if isNatTok v then some () else none
  | none => none

/-- The `subject=` tail: the last field of a mint line, whose value may
    carry `=`/spaces — and, if an evaluated arg renders one, a tab. The
    key must head the remainder; everything after it rides verbatim. -/
def subjectTail : List String → Bool
  | [] => false
  | p :: _ => p.startsWith "subject="

def parseLine (lineno : Nat) (line : String) : Option Ev :=
  -- tolerate a CR tail only: the writer emits LF, a checked-out or copied
  -- corpus may arrive CRLF — that is line-format noise, not content
  let line := if line.endsWith "\r" then (line.dropEnd 1).toString else line
  if line.isEmpty then none else
  match line.splitOn "\t" with
  | "session-open" :: [tTok, sTok] =>
    match fieldTs tTok, fieldVal sTok "session" with
    | some _, some s => some ⟨.sessionOpen, s, "", lineno⟩
    | _, _ => none
  | "session-closed" :: [tTok, sTok] =>
    match fieldTs tTok, fieldVal sTok "session" with
    | some _, some s => some ⟨.sessionClosed, s, "", lineno⟩
    | _, _ => none
  | "use" :: [tTok, sTok, hTok, vTok] =>
    match fieldTs tTok, fieldVal sTok "session", fieldVal hTok "handle", fieldVal vTok "verb" with
    | some _, some s, some h, some _ => some ⟨.use, s, h, lineno⟩
    | _, _, _, _ => none
  | "release" :: [tTok, sTok, hTok, bTok] =>
    match fieldTs tTok, fieldVal sTok "session", fieldVal hTok "handle", fieldVal bTok "by" with
    | some _, some s, some h, some _ => some ⟨.release, s, h, lineno⟩
    | _, _, _, _ => none
  | "mint" :: tTok :: sTok :: hTok :: vTok :: tyTok :: subjRest =>
    match fieldTs tTok, fieldVal sTok "session", fieldVal hTok "handle",
          fieldVal vTok "verb", fieldVal tyTok "type" with
    | some _, some s, some h, some _, some _ =>
      if subjectTail subjRest then some ⟨.mint, s, h, lineno⟩ else none
    | _, _, _, _, _ => none
  | _ => none

/-! ## The ledger -/

/-- One session's span: `open_` while between `session-open` and
    `session-closed`; `live` = minted-not-yet-released handles, `dead` =
    handles settled this span (kept so a second release names
    `double-release` rather than `release-of-unminted`). -/
structure Span where
  session : String
  open_ : Bool
  live : List String
  dead : List String
deriving Repr

/-- Structural lookup — kept recursive rather than `List.find?` so the
    cons case is an `if`-split by `rfl`, which is all the proofs below ask
    of it. -/
def findSpan : List Span → String → Option Span
  | [], _ => none
  | x :: rest, s => if x.session == s then some x else findSpan rest s

def putSpan (spans : List Span) (sp : Span) : List Span :=
  sp :: spans.filter (·.session != sp.session)

@[simp] theorem findSpan_nil (s : String) : findSpan [] s = none := rfl

theorem findSpan_cons (x : Span) (rest : List Span) (s : String) :
    findSpan (x :: rest) s = (if x.session == s then some x else findSpan rest s) := rfl

/-- One event applied to the ledger. On a violation the state is left
    unchanged — a forged line is noise, not history — and replay keeps
    reading so one bad event cannot hide a second. -/
def step (spans : List Span) (e : Ev) : Option String × List Span :=
  match e.kind with
  | .sessionOpen =>
    match findSpan spans e.session with
    | none => (none, ⟨e.session, true, [], []⟩ :: spans)
    | some sp =>
      if sp.open_ then
        (some s!"reopen: session '{e.session}' opened while open (line {e.line})", spans)
      else (none, putSpan spans ⟨sp.session, true, [], []⟩)
  | .sessionClosed =>
    match findSpan spans e.session with
    | none => (some s!"close-of-unopened: '{e.session}' (line {e.line})", spans)
    | some sp =>
      if !sp.open_ then
        (some s!"close-of-unopened: '{e.session}' span already closed (line {e.line})", spans)
      else
        -- the close DID happen; what is missing is the releases, so the
        -- span still ends — flag the violation, keep the history
        if sp.live.isEmpty then
          (none, putSpan spans ⟨sp.session, false, sp.live, sp.dead⟩)
        else
          (some s!"unreleased-at-close: '{e.session}' closed holding {sp.live} (line {e.line})",
           putSpan spans ⟨sp.session, false, sp.live, sp.dead⟩)
  | .mint =>
    match findSpan spans e.session with
    | none =>
      (some s!"mint-outside-session: '{e.handle}' in '{e.session}' (line {e.line})", spans)
    | some sp =>
      if !sp.open_ then
        (some s!"mint-outside-session: '{e.handle}' in '{e.session}' (line {e.line})", spans)
      else if e.handle ∈ sp.live then
        (some s!"double-mint: '{e.handle}' in '{e.session}' (line {e.line})", spans)
      else (none, putSpan spans ⟨sp.session, sp.open_, e.handle :: sp.live,
                                 sp.dead.erase e.handle⟩)
  | .use =>
    match findSpan spans e.session with
    | none =>
      (some s!"use-outside-session: '{e.handle}' in '{e.session}' (line {e.line})", spans)
    | some sp =>
      if !sp.open_ then
        (some s!"use-outside-session: '{e.handle}' in '{e.session}' (line {e.line})", spans)
      else if e.handle ∈ sp.live then
        -- a borrow exercises; it does not mint, move, or settle — the
        -- ledger is untouched and the span's touched-order is unchanged
        (none, spans)
      else if e.handle ∈ sp.dead then
        (some s!"use-of-released: '{e.handle}' in '{e.session}' (line {e.line})", spans)
      else
        (some s!"use-of-unminted: '{e.handle}' in '{e.session}' (line {e.line})", spans)
  | .release =>
    match findSpan spans e.session with
    | none =>
      (some s!"release-outside-session: '{e.handle}' in '{e.session}' (line {e.line})", spans)
    | some sp =>
      if !sp.open_ then
        (some s!"release-outside-session: '{e.handle}' in '{e.session}' (line {e.line})", spans)
      else if e.handle ∈ sp.live then
        (none, putSpan spans ⟨sp.session, sp.open_, sp.live.filter (· != e.handle),
                              e.handle :: sp.dead.erase e.handle⟩)
      else if e.handle ∈ sp.dead then
        (some s!"double-release: '{e.handle}' in '{e.session}' (line {e.line})", spans)
      else
        (some s!"release-of-unminted: '{e.handle}' in '{e.session}' (line {e.line})", spans)

/-- End-of-log sweep: no span may remain open. `died-holding` names the
    live handles; an open span holding nothing is `unclosed-session` —
    both are `malformed` class (the ledger did not close), the codes stay
    distinct (a faithful record of a dead process is not corruption). -/
def spanCheck (spans : List Span) : List String :=
  (spans.filter (·.open_)).map fun sp =>
    if sp.live.isEmpty then s!"unclosed-session: '{sp.session}'"
    else s!"died-holding: '{sp.session}' holding {sp.live}"

/-- The collecting fold's step, named so proofs can rewrite it. -/
def stepAcc (acc : List Span × List String) (e : Ev) : List Span × List String :=
  match step acc.1 e with
  | (none, spans') => (spans', acc.2)
  | (some r, spans') => (spans', acc.2 ++ [r])

/-- Collecting replay — every violation is reported, in file order. -/
def checkEvs (evs : List Ev) : List Span × List String :=
  evs.foldl stepAcc ([], [])

/-- Strict replay — aborts on the first illegal event. Used by the
    meta-theory: a collecting run with no violations IS a strict run. -/
def replay : List Ev → List Span → Except String (List Span)
  | [], st => .ok st
  | e :: rest, st =>
    match step st e with
    | (some r, _) => .error r
    | (none, st') => replay rest st'

/-- Parse every line; a grammar failure is recorded and the line is not
    an event (a non-event cannot move custody — consistent with the
    witness channel dropping unparsed lines while flagging them). -/
def parseLines : Nat → List String → List String × List Ev
  | _, [] => ([], [])
  | i, l :: rest =>
    match parseLine i l, parseLines (i + 1) rest with
    | some e, (vs, es) => (vs, e :: es)
    | none,  (vs, es) => (s!"grammar: line {i} is not a custody event" :: vs, es)

/-- The file-level check: every line parses, every event is legal, no
    span remains open. Empty result = clean ledger. Written with bare
    projections (no `let`) so `clean_sound` can rewrite through it. -/
def checkLog (lines : List String) : List String :=
  (parseLines 1 lines).1 ++
    (checkEvs (parseLines 1 lines).2).2 ++
    spanCheck (checkEvs (parseLines 1 lines).2).1

/-! ## Reference semantics (Role A spec)

`heldSpec` answers "is `(s,h)` held after this event list" WITHOUT the
ledger's bookkeeping: scan most-recent-first; the latest event touching
`(s,h)` decides, and a span boundary for `s` erases everything before it.
Two independent derivations — a bug in the ledger's `live`-set arithmetic
shows up as disagreement, not as two copies of the same bug. -/

/-- Does `e` write the custody of `(s,h)`: a mint or release of this
    handle in this session, or a span boundary for this session (which
    erases all its holds). -/
def touchesOrResets (e : Ev) (s h : String) : Bool :=
  e.session == s &&
    (e.kind == .sessionOpen || e.kind == .sessionClosed ||
     (e.handle == h && (e.kind == .mint || e.kind == .release)))

/-- The scan, most-recent-first: a touching mint leaves `h` held; any
    other touch (release, either span mark) leaves it not held. -/
def heldScan : List Ev → String → String → Bool
  | [], _, _ => false
  | e :: rest, s, h =>
    if touchesOrResets e s h then e.kind == .mint else heldScan rest s h

def heldSpec (evs : List Ev) (s h : String) : Bool :=
  heldScan evs.reverse s h

/-- What the ledger claims `(s,h)`'s custody is. -/
def liveHolds (spans : List Span) (s h : String) : Bool :=
  match findSpan spans s with
  | none => false
  | some sp => sp.open_ && sp.live.contains h

/-! ## Small lemmas about the state container -/

theorem findSpan_none (spans : List Span) (s : String)
    (h : findSpan spans s = none) : ∀ sp ∈ spans, sp.session ≠ s := by
  induction spans with
  | nil => intro sp hm; cases hm
  | cons x rest ih =>
    rw [findSpan_cons] at h
    split at h
    · exact absurd h (by simp)
    · intro sp' hm
      cases hm with
      | head =>
        intro heq
        rename_i hx
        rw [heq] at hx
        simp at hx
      | tail _ hm' => exact ih h sp' hm'

theorem findSpan_some (spans : List Span) (s : String) (sp : Span)
    (h : findSpan spans s = some sp) : sp.session = s ∧ sp ∈ spans := by
  induction spans with
  | nil => simp at h
  | cons x rest ih =>
    rw [findSpan_cons] at h
    split at h
    · rename_i hx
      have hxs : x.session = s := by simpa [beq_iff_eq] using hx
      have : x = sp := by simpa using h
      subst this
      exact ⟨hxs, .head _⟩
    · obtain ⟨hs, hm⟩ := ih h
      exact ⟨hs, .tail _ hm⟩

/-- A filtered list's lookup agrees with the unfiltered one when the
    filter only removes a different session id: every candidate for
    `session == s` survives a `!= keep` filter when `s ≠ keep`. -/
theorem findSpan_filter (spans : List Span) (s keep : String) (hne : s ≠ keep) :
    findSpan (spans.filter (·.session != keep)) s = findSpan spans s := by
  induction spans with
  | nil => rfl
  | cons x rest ih =>
    simp only [List.filter_cons, findSpan]
    by_cases hxk : x.session == keep
    · -- x is filtered out; x cannot match s (its session IS keep)
      have hf : ¬((x.session != keep) = true) := by simp [bne, hxk]
      rw [if_neg hf]
      by_cases hxs : x.session == s
      · have hxsk : x.session = keep := by simpa [beq_iff_eq] using hxk
        have hxs' : x.session = s := by simpa [beq_iff_eq] using hxs
        exact absurd (hxs' ▸ hxsk) hne
      · rw [if_neg hxs]; exact ih
    · have ht : (x.session != keep) = true := by simp [bne, hxk]
      rw [if_pos ht, findSpan_cons]
      by_cases hxs : x.session == s
      · rw [if_pos hxs, if_pos hxs]
      · rw [if_neg hxs, if_neg hxs]; exact ih

/-- After a `putSpan`, lookup of `sp.session` hits `sp`; any other id
    looks up in the original list (the filter removed only `sp.session`'s
    entry, and `findSpan_filter` collapses the rest). -/
theorem findSpan_putSpan (spans : List Span) (sp : Span) (s : String) :
    findSpan (putSpan spans sp) s =
      if s == sp.session then some sp else findSpan spans s := by
  unfold putSpan
  rw [findSpan_cons]
  by_cases hss : sp.session == s
  · rw [if_pos hss, if_pos (beq_iff_eq.mpr (beq_iff_eq.mp hss).symm)]
  · have hs : ¬(s == sp.session) := fun h => hss (beq_iff_eq.mpr (beq_iff_eq.mp h).symm)
    rw [if_neg hss, if_neg hs]
    apply findSpan_filter
    intro heq
    exact hs (beq_iff_eq.mpr heq)

/-- The released-handle filter removes exactly `a` — unconditionally,
    with no duplicate-freeness assumed of `live` (which is why `release`
    filters rather than `erase`es: `erase` drops only the first copy and
    would silently survive a bookkeeping bug that duplicated a hold). -/
theorem contains_filter_ne (l : List String) (a b : String) :
    (l.filter (· != a)).contains b = (b != a && l.contains b) := by
  rw [List.contains_eq_mem, List.contains_eq_mem]
  by_cases hb : b == a
  · have hba : b = a := beq_iff_eq.mp hb
    subst hba
    simp [List.mem_filter, bne]
  · have hba : (b != a) = true := by
      simp [bne]; intro h; exact hb (beq_iff_eq.mpr h)
    rw [hba]; simp only [Bool.true_and]
    by_cases hm : b ∈ l
    · have hf : b ∈ l.filter (· != a) :=
        List.mem_filter.mpr ⟨hm, hba⟩
      simp [hm, hf]
    · have hf : b ∉ l.filter (· != a) :=
        fun h => hm (List.mem_filter.mp h).1
      simp [hm, hf]

/-! ## Role A: ledger = reference scan -/

theorem heldScan_cons (e : Ev) (rest : List Ev) (s h : String) :
    heldScan (e :: rest) s h =
      (if touchesOrResets e s h then e.kind == .mint else heldScan rest s h) := rfl

/-- Appending one event: the scan sees the new event first. -/
theorem heldSpec_snoc (pre : List Ev) (e : Ev) (s h : String) :
    heldSpec (pre ++ [e]) s h =
      if touchesOrResets e s h then e.kind == .mint else heldSpec pre s h := by
  unfold heldSpec
  rw [List.reverse_append, List.reverse_singleton, List.singleton_append]
  exact heldScan_cons e pre.reverse s h

/-- `liveHolds` after a `putSpan`, stated over fields so the produced
    span never appears under a projection. -/
theorem liveHolds_putSpan (spans : List Span) (sess : String) (o : Bool)
    (lv dd : List String) (s h : String) :
    liveHolds (putSpan spans ⟨sess, o, lv, dd⟩) s h =
      if s == sess then (o && lv.contains h) else liveHolds spans s h := by
  unfold liveHolds
  rw [findSpan_putSpan]
  show (match (if s == sess then some (⟨sess, o, lv, dd⟩ : Span) else findSpan spans s) with
        | none => false | some sp => sp.open_ && sp.live.contains h) =
       if s == sess then (o && lv.contains h)
       else match findSpan spans s with | none => false | some sp => sp.open_ && sp.live.contains h
  by_cases hss : s == sess
  · rw [if_pos hss, if_pos hss]
  · rw [if_neg hss, if_neg hss]

theorem liveHolds_fresh (spans : List Span) (sess s h : String) :
    liveHolds (⟨sess, true, [], []⟩ :: spans) s h =
      if sess == s then false else liveHolds spans s h := by
  unfold liveHolds
  rw [findSpan_cons]
  show (match (if sess == s then some (⟨sess, true, [], []⟩ : Span) else findSpan spans s) with
        | none => false | some sp => sp.open_ && sp.live.contains h) = _
  by_cases hs : sess == s
  · rw [if_pos hs, if_pos hs]
    rfl
  · rw [if_neg hs, if_neg hs]

/-- `touchesOrResets` facts, in the shape the step cases consume. -/
theorem touches_of_session_ne (e : Ev) (s h : String) (hne : e.session ≠ s) :
    touchesOrResets e s h = false := by
  unfold touchesOrResets
  have hbf : (e.session == s) = false := by
    cases hcs : e.session == s
    · rfl
    · exact absurd (beq_iff_eq.mp hcs) hne
  rw [hbf]; rfl

theorem touches_span_boundary (e : Ev) (s : String) (hs : e.session = s)
    (hk : e.kind = .sessionOpen ∨ e.kind = .sessionClosed) (h : String) :
    touchesOrResets e s h = true := by
  unfold touchesOrResets
  cases hk with
  | inl hk => rw [hk]; simp [hs]
  | inr hk => rw [hk]; simp [hs]

theorem touches_handle (e : Ev) (s h : String) (hs : e.session = s)
    (hh : e.handle = h) (hk : e.kind = .mint ∨ e.kind = .release) :
    touchesOrResets e s h = true := by
  unfold touchesOrResets
  cases hk with
  | inl hk => rw [hk]; simp [hs, hh]
  | inr hk => rw [hk]; simp [hs, hh]

/-- A `use` writes no custody: it is neither a span boundary nor a
    mint/release touch, so `touchesOrResets` is false whatever `(s,h)` —
    held-ness survives an exercise unchanged, by definition. -/
theorem touches_use (e : Ev) (s h : String) (hk : e.kind = .use) :
    touchesOrResets e s h = false := by
  unfold touchesOrResets
  rw [hk]; simp

theorem not_touches_handle (e : Ev) (s h : String) (hs : e.session = s)
    (hh : e.handle ≠ h) (hk : e.kind = .mint ∨ e.kind = .release) :
    touchesOrResets e s h = false := by
  unfold touchesOrResets
  cases hk with
  | inl hk =>
    rw [hk]
    simp only [beq_iff_eq.mpr hs, Bool.true_and]
    have hb : (e.handle == h) = false := by
      cases hc : e.handle == h
      · rfl
      · exact absurd (beq_iff_eq.mp hc) hh
    rw [hb]; rfl
  | inr hk =>
    rw [hk]
    simp only [beq_iff_eq.mpr hs, Bool.true_and]
    have hb : (e.handle == h) = false := by
      cases hc : e.handle == h
      · rfl
      · exact absurd (beq_iff_eq.mp hc) hh
    rw [hb]; rfl

/-- An accepted `step` preserves the invariant `liveHolds ↔ heldSpec`:
    the ledger's `live` set and the reference scan agree after every
    legal event. This is the simulation at the heart of the whole proof —
    each event kind updates both sides identically. -/
theorem step_inv (e : Ev) (spans spans' : List Span)
    (hs : step spans e = (none, spans'))
    (pre : List Ev)
    (hinv : ∀ s h, liveHolds spans s h = heldSpec pre s h) :
    ∀ s h, liveHolds spans' s h = heldSpec (pre ++ [e]) s h := by
  intro s h
  rw [heldSpec_snoc]
  cases e with
  | mk kind sess hdl ln =>
    cases kind with
    | sessionOpen =>
      simp only [step] at hs
      split at hs
      · rename_i hfs
        rw [Prod.mk.injEq] at hs
        obtain ⟨_, hsub⟩ := hs
        subst hsub
        rw [liveHolds_fresh]
        by_cases hss : sess == s
        · have hse : sess = s := beq_iff_eq.mp hss
          rw [if_pos hss, if_pos (touches_span_boundary _ _ hse (.inl rfl) h)]
          rfl
        · have hne : sess ≠ s := fun hh => hss (beq_iff_eq.mpr hh)
          rw [if_neg hss, touches_of_session_ne _ s h hne]
          exact hinv s h
      · rename_i sp hfs
        split at hs
        · rename_i hop; simp at hs  -- reopen of open span: refused
        · rename_i hop
          rw [Prod.mk.injEq] at hs
          obtain ⟨_, hsub⟩ := hs
          subst hsub
          rw [liveHolds_putSpan]
          have hsp : sp.session = sess := (findSpan_some spans sess sp hfs).1
          by_cases hss : s == sp.session
          · have hse : sess = s := by rw [← hsp]; exact (beq_iff_eq.mp hss).symm
            rw [if_pos hss, if_pos (touches_span_boundary _ _ hse (.inl rfl) h)]
            rfl
          · have hne : sess ≠ s := fun hh => hss (beq_iff_eq.mpr (hsp.trans hh).symm)
            rw [if_neg hss, touches_of_session_ne _ s h hne]
            exact hinv s h
    | sessionClosed =>
      simp only [step] at hs
      split at hs
      · rename_i hfs; simp at hs
      · rename_i sp hfs
        split at hs
        · rename_i hop; simp at hs  -- close of already-closed: refused
        · rename_i hop
          split at hs
          · rename_i hlive
            rw [Prod.mk.injEq] at hs
            obtain ⟨_, hsub⟩ := hs
            subst hsub
            rw [liveHolds_putSpan]
            have hsp : sp.session = sess := (findSpan_some spans sess sp hfs).1
            by_cases hss : s == sp.session
            · have hse : sess = s := by rw [← hsp]; exact (beq_iff_eq.mp hss).symm
              rw [if_pos hss, if_pos (touches_span_boundary _ _ hse (.inr rfl) h)]
              rfl
            · have hne : sess ≠ s := fun hh => hss (beq_iff_eq.mpr (hsp.trans hh).symm)
              rw [if_neg hss, touches_of_session_ne _ s h hne]
              exact hinv s h
          · rename_i hlive; simp at hs  -- unreleased-at-close: refused
    | mint =>
      simp only [step] at hs
      split at hs
      · rename_i hfs; simp at hs  -- no span: refused
      · rename_i sp hfs
        split at hs
        · rename_i hop; simp at hs  -- closed span: refused
        · rename_i hop
          split at hs
          · rename_i hmem; simp at hs  -- double-mint: refused
          · rename_i hmem
            rw [Prod.mk.injEq] at hs
            obtain ⟨_, hsub⟩ := hs
            subst hsub
            rw [liveHolds_putSpan]
            have hsp : sp.session = sess := (findSpan_some spans sess sp hfs).1
            have hop' : sp.open_ = true := by
              cases ho : sp.open_ with
              | true => rfl
              | false => simp [ho] at hop
            by_cases hss : s == sp.session
            · have hssess : s = sess := (beq_iff_eq.mp hss).trans hsp
              have hse : sess = s := hssess.symm
              rw [if_pos hss, hop', List.contains_cons]
              simp only [Bool.true_and]
              by_cases hh : h == hdl
              · rw [hh]
                simp only [Bool.true_or]
                have hhd : hdl = h := (beq_iff_eq.mp hh).symm
                rw [if_pos (touches_handle _ _ _ hse hhd (.inl rfl))]
                rfl
              · have hhf : (h == hdl) = false := by
                  rw [← Bool.not_eq_true]; exact hh
                rw [hhf]
                simp only [Bool.false_or]
                have hhd : hdl ≠ h := fun he => hh (beq_iff_eq.mpr he.symm)
                rw [not_touches_handle _ _ _ hse hhd (.inl rfl)]
                rw [hssess]
                have hh0 := hinv s h
                unfold liveHolds at hh0
                rw [hssess] at hh0
                rw [hfs] at hh0
                replace hh0 : (sp.open_ && sp.live.contains h) = heldSpec pre sess h := hh0
                rw [hop'] at hh0
                simp only [Bool.true_and] at hh0
                exact hh0
            · have hne : sess ≠ s := fun hh => hss (beq_iff_eq.mpr (hsp.trans hh).symm)
              rw [if_neg hss, touches_of_session_ne _ s h hne]
              exact hinv s h
    | use =>
      simp only [step] at hs
      split at hs
      · rename_i hfs; simp at hs  -- no span: refused
      · rename_i sp hfs
        split at hs
        · rename_i hop; simp at hs  -- closed span: refused
        · rename_i hop
          split at hs
          · rename_i hmem
            -- accepted: the state is returned unchanged — custody did
            -- not move, so the invariant carries over verbatim
            rw [Prod.mk.injEq] at hs
            obtain ⟨_, hsub⟩ := hs
            subst hsub
            have ht : ¬(touchesOrResets ⟨.use, sess, hdl, ln⟩ s h = true) := by
              rw [touches_use _ _ _ rfl]; simp
            rw [if_neg ht]
            exact hinv s h
          · -- dead → use-of-released, else use-of-unminted — refused
            split at hs <;> · rename_i hmem hdead; simp at hs
    | release =>
      simp only [step] at hs
      split at hs
      · rename_i hfs; simp at hs
      · rename_i sp hfs
        split at hs
        · rename_i hop; simp at hs
        · rename_i hop
          split at hs
          · rename_i hmem
            rw [Prod.mk.injEq] at hs
            obtain ⟨_, hsub⟩ := hs
            subst hsub
            rw [liveHolds_putSpan]
            have hsp : sp.session = sess := (findSpan_some spans sess sp hfs).1
            have hop' : sp.open_ = true := by
              cases ho : sp.open_ with
              | true => rfl
              | false => simp [ho] at hop
            by_cases hss : s == sp.session
            · have hssess : s = sess := (beq_iff_eq.mp hss).trans hsp
              have hse : sess = s := hssess.symm
              rw [if_pos hss, hop', contains_filter_ne]
              simp only [Bool.true_and]
              by_cases hh : h == hdl
              · have hne2 : (h != hdl) = false := by
                  simp only [bne, hh, Bool.not_true]
                rw [hne2]; simp only [Bool.false_and]
                have hhd : hdl = h := (beq_iff_eq.mp hh).symm
                rw [if_pos (touches_handle _ _ _ hse hhd (.inr rfl))]
                rfl
              · have hhf : (h == hdl) = false := by
                  rw [← Bool.not_eq_true]; exact hh
                have hne2 : (h != hdl) = true := by
                  simp only [bne, hhf, Bool.not_false]
                rw [hne2]; simp only [Bool.true_and]
                have hhd : hdl ≠ h := fun he => hh (beq_iff_eq.mpr he.symm)
                rw [not_touches_handle _ _ _ hse hhd (.inr rfl)]
                rw [hssess]
                have hh0 := hinv s h
                unfold liveHolds at hh0
                rw [hssess] at hh0
                rw [hfs] at hh0
                replace hh0 : (sp.open_ && sp.live.contains h) = heldSpec pre sess h := hh0
                rw [hop'] at hh0
                simp only [Bool.true_and] at hh0
                exact hh0
            · have hne : sess ≠ s := fun hh => hss (beq_iff_eq.mpr (hsp.trans hh).symm)
              rw [if_neg hss, touches_of_session_ne _ s h hne]
              exact hinv s h
          · -- hdl ∉ live: dead → double-release, else unminted — refused
            split at hs <;> · rename_i hmem hdead; simp at hs

/-- An accepted release step says the handle was live in its span —
    the ledger side of "every release is backed by a live mint". -/
theorem step_release_holds (spans : List Span) (e : Ev) (spans' : List Span)
    (hs : step spans e = (none, spans')) (hk : e.kind = .release) :
    liveHolds spans e.session e.handle = true := by
  simp only [step] at hs
  rw [hk] at hs
  dsimp only at hs
  split at hs
  · rename_i hfs; simp at hs
  · rename_i sp hfs
    split at hs
    · rename_i hop; simp at hs
    · rename_i hop
      split at hs
      · rename_i hmem
        unfold liveHolds
        rw [hfs]
        show (sp.open_ && sp.live.contains e.handle) = true
        have hop' : sp.open_ = true := by
          cases ho : sp.open_ with
          | true => rfl
          | false => simp [ho] at hop
        rw [hop', List.contains_eq_mem]
        simp [hmem]
      · split at hs <;> · rename_i hmem hdead; simp at hs

/-- An accepted `use` step says the handle was live in its span —
    the ledger side of "every exercise was backed by a hold". -/
theorem step_use_holds (spans : List Span) (e : Ev) (spans' : List Span)
    (hs : step spans e = (none, spans')) (hk : e.kind = .use) :
    liveHolds spans e.session e.handle = true := by
  simp only [step] at hs
  rw [hk] at hs
  dsimp only at hs
  split at hs
  · rename_i hfs; simp at hs
  · rename_i sp hfs
    split at hs
    · rename_i hop; simp at hs
    · rename_i hop
      split at hs
      · rename_i hmem
        unfold liveHolds
        rw [hfs]
        show (sp.open_ && sp.live.contains e.handle) = true
        have hop' : sp.open_ = true := by
          cases ho : sp.open_ with
          | true => rfl
          | false => simp [ho] at hop
        rw [hop', List.contains_eq_mem]
        simp [hmem]
      · split at hs <;> · rename_i hmem hdead; simp at hs

/-! ## Lifting to a run -/

/-- Strict replay preserves the invariant and makes every accepted
    release — and every accepted exercise — a held one. `pre` carries
    the already-consumed prefix so the induction generalizes over
    position. -/
theorem replay_all : ∀ (evs : List Ev) (st st' : List Span) (pre : List Ev),
    replay evs st = .ok st' →
    (∀ s h, liveHolds st s h = heldSpec pre s h) →
    (∀ s h, liveHolds st' s h = heldSpec (pre ++ evs) s h) ∧
    (∀ past e' future, evs = past ++ e' :: future →
       e'.kind = .release ∨ e'.kind = .use →
       heldSpec (pre ++ past) e'.session e'.handle = true) := by
  intro evs
  induction evs with
  | nil =>
    intro st st' pre hok hinv
    simp [replay] at hok
    subst st'
    refine ⟨by simpa using hinv, ?_⟩
    intro past e' future hsplit
    cases past with
    | nil => simp at hsplit
    | cons p past' => simp at hsplit
  | cons e rest ih =>
    intro st st' pre hok hinv
    unfold replay at hok
    split at hok
    · rename_i v st1 hstep
      simp at hok
    · rename_i st1 hstep
      have hinv' : ∀ s h, liveHolds st1 s h = heldSpec (pre ++ [e]) s h :=
        step_inv e st st1 hstep pre hinv
      obtain ⟨hend, hrel⟩ := ih st1 st' (pre ++ [e]) hok hinv'
      refine ⟨?_, ?_⟩
      · intro s h
        have := hend s h
        rwa [List.append_assoc, List.singleton_append] at this
      · intro past e' future hsplit hk
        cases past with
        | nil =>
          simp at hsplit
          obtain ⟨rfl, rfl⟩ := hsplit
          have hheld : liveHolds st e.session e.handle = true := by
            cases hk with
            | inl hr => exact step_release_holds st e st1 hstep hr
            | inr hu => exact step_use_holds st e st1 hstep hu
          rw [hinv e.session e.handle] at hheld
          simpa using hheld
        | cons p past' =>
          simp at hsplit
          obtain ⟨rfl, rfl⟩ := hsplit
          have := hrel past' e' future rfl hk
          rwa [List.append_assoc, List.singleton_append] at this

/-- A clean run from the empty ledger: `liveHolds` tracks `heldSpec`
    throughout, and every release or exercise had a live hold behind it. -/
theorem replay_nil_sound (evs : List Ev) (st' : List Span)
    (hok : replay evs [] = .ok st') :
    (∀ s h, liveHolds st' s h = heldSpec evs s h) ∧
    (∀ past e' future, evs = past ++ e' :: future →
       e'.kind = .release ∨ e'.kind = .use →
       heldSpec past e'.session e'.handle = true) := by
  have hinv0 : ∀ s h, liveHolds [] s h = heldSpec [] s h := fun s h => rfl
  obtain ⟨hend, hrel⟩ := replay_all evs [] st' [] hok hinv0
  refine ⟨?_, ?_⟩
  · intro s h
    have := hend s h
    rwa [List.nil_append] at this
  · intro past e' future hs hk
    have := hrel past e' future hs hk
    rwa [List.nil_append] at this

/-! ## The pairing: held ⇒ a mint with no intervening settle -/

/-- `heldScan` finds the deciding mint: scanning `xs` (most recent first)
    reports `(s,h)` held only if a mint of `(s,h)` sits before any other
    event touching `(s,h)`. -/
theorem heldScan_true {xs : List Ev} {s h : String} :
    heldScan xs s h = true →
    ∃ pre mid post, xs = pre ++ mid :: post ∧
      mid.kind = .mint ∧ mid.session = s ∧ mid.handle = h ∧
      ∀ e' ∈ pre, touchesOrResets e' s h = false := by
  induction xs with
  | nil => intro hs; simp [heldScan] at hs
  | cons e rest ih =>
    intro hs
    rw [heldScan_cons] at hs
    by_cases ht : touchesOrResets e s h
    · rw [if_pos ht] at hs
      have hkind : e.kind = .mint := by
        cases hkc : e.kind <;> simp_all
      have hsh : e.session = s ∧ e.handle = h := by
        unfold touchesOrResets at ht
        rw [hkind] at ht
        simp [beq_iff_eq] at ht
        exact ht
      exact ⟨[], e, rest, rfl, hkind, hsh.1, hsh.2, fun e' he' => by simp at he'⟩
    · rw [if_neg ht] at hs
      obtain ⟨pre, mid, post, hxs, hkind, hses, hhd, hpre⟩ := ih hs
      have htf : touchesOrResets e s h = false := by
        rw [← Bool.not_eq_true]; exact ht
      refine ⟨e :: pre, mid, post, ?_, hkind, hses, hhd, ?_⟩
      · rw [hxs, List.cons_append]
      · intro e' he'
        cases List.mem_cons.mp he' with
        | inl hh => rw [hh]; exact htf
        | inr hm => exact hpre e' hm

/-- On the original order: `(s,h)` held at the end ⇒ an earlier mint of
    `(s,h)` with no settling event after it. -/
theorem heldSpec_true {evs : List Ev} {s h : String} :
    heldSpec evs s h = true →
    ∃ earlier mid later, evs = earlier ++ mid :: later ∧
      mid.kind = .mint ∧ mid.session = s ∧ mid.handle = h ∧
      ∀ e' ∈ later, touchesOrResets e' s h = false := by
  intro hh
  unfold heldSpec at hh
  obtain ⟨pre, mid, post, hxs, hkind, hses, hhd, hpre⟩ := heldScan_true hh
  refine ⟨post.reverse, mid, pre.reverse, ?_, hkind, hses, hhd, ?_⟩
  · calc evs = evs.reverse.reverse := (List.reverse_reverse _).symm
      _ = (pre ++ mid :: post).reverse := by rw [hxs]
      _ = (mid :: post).reverse ++ pre.reverse := List.reverse_append
      _ = (post.reverse ++ [mid]) ++ pre.reverse := by rw [List.reverse_cons]
      _ = post.reverse ++ mid :: pre.reverse := by rw [List.append_assoc]; rfl
  · intro e' he'
    exact hpre e' (List.mem_reverse.mp he')

/-! ## The file-level verdict -/

/-- A collecting fold that produced no violations is a strict replay. -/
theorem checkEvs_clean_aux : ∀ (evs : List Ev) (st : List Span) (vs : List String),
    (evs.foldl stepAcc (st, vs)).2 = [] →
    vs = [] ∧ replay evs st = .ok (evs.foldl stepAcc (st, vs)).1 := by
  intro evs
  induction evs with
  | nil =>
    intro st vs hacc
    simp only [List.foldl_nil] at hacc ⊢
    exact ⟨hacc, rfl⟩
  | cons e rest ih =>
    intro st vs hacc
    rw [List.foldl_cons] at hacc
    cases hstep : step st e with
    | mk r st1 =>
      cases r with
      | none =>
        have hsa : stepAcc (st, vs) e = (st1, vs) := by simp [stepAcc, hstep]
        rw [hsa] at hacc
        obtain ⟨hvs, hrep⟩ := ih st1 vs hacc
        subst hvs
        refine ⟨rfl, ?_⟩
        unfold replay
        rw [hstep]
        show replay rest st1 = .ok ((e :: rest).foldl stepAcc (st, [])).1
        rw [List.foldl_cons, hsa]
        exact hrep
      | some r =>
        have hsa : stepAcc (st, vs) e = (st1, vs ++ [r]) := by simp [stepAcc, hstep]
        rw [hsa] at hacc
        obtain ⟨hvs, _⟩ := ih st1 (vs ++ [r]) hacc
        simp at hvs

theorem checkEvs_clean (evs : List Ev) (spans' : List Span)
    (h : checkEvs evs = (spans', [])) : replay evs [] = .ok spans' := by
  unfold checkEvs at h
  have h1 : (evs.foldl stepAcc ([], [])).1 = spans' := congrArg Prod.fst h
  have h2 : (evs.foldl stepAcc ([], [])).2 = [] := congrArg Prod.snd h
  obtain ⟨_, hrep⟩ := checkEvs_clean_aux evs [] [] h2
  rwa [h1] at hrep

/-- `spanCheck` empty: no span open at end ⇒ nothing held anywhere. -/
theorem spanCheck_nil (spans : List Span) (h : spanCheck spans = []) :
    ∀ s hd, liveHolds spans s hd = false := by
  intro s hd
  have hclosed : ∀ sp ∈ spans, sp.open_ = false := by
    intro sp hm
    by_cases ho : (sp.open_ = true)
    · have hmem : sp ∈ spans.filter (·.open_) :=
        List.mem_filter.mpr ⟨hm, ho⟩
      have hf : spans.filter (·.open_) = [] := by
        have hl := congrArg List.length h
        unfold spanCheck at hl
        simp only [List.length_map, List.length_nil] at hl
        exact List.eq_nil_of_length_eq_zero hl
      rw [hf] at hmem
      simp at hmem
    · cases hb : sp.open_ with
      | false => rfl
      | true => exact absurd hb ho
  unfold liveHolds
  cases hfs : findSpan spans s with
  | none => rfl
  | some sp =>
    obtain ⟨_, hm⟩ := findSpan_some spans s sp hfs
    dsimp only
    rw [hclosed sp hm]
    rfl

/-- The headline theorem: `checkLog` empty certifies a lawful ledger —
    nothing held anywhere at end of file, and every release and every
    use was backed by a live mint at its position (via
    `replay_nil_sound`), which `heldSpec_true` upgrades to an earlier
    mint of the same `(session, handle)` with no settling event between
    them. -/
theorem clean_sound (lines : List String) (hc : checkLog lines = [])
    (evs : List Ev) (hpar : parseLines 1 lines = ([], evs)) :
    (∀ s h, heldSpec evs s h = false) ∧
    (∀ past e future, evs = past ++ e :: future →
       e.kind = .release ∨ e.kind = .use →
       heldSpec past e.session e.handle = true) := by
  simp only [checkLog] at hc
  rw [hpar] at hc
  dsimp only at hc
  rw [List.nil_append] at hc
  -- hc : (checkEvs evs).2 ++ spanCheck (checkEvs evs).1 = []
  obtain ⟨hlv, hsp⟩ := List.append_eq_nil_iff.mp hc
  cases hce : checkEvs evs with
  | mk spans lv =>
    rw [hce] at hlv hsp
    dsimp only at hlv hsp
    have hce' : checkEvs evs = (spans, []) :=
      hce.trans (congrArg (fun x => (spans, x)) hlv)
    have hrep : replay evs [] = .ok spans := checkEvs_clean evs spans hce'
    obtain ⟨hend, hrel⟩ := replay_nil_sound evs spans hrep
    have hnothing := spanCheck_nil spans hsp
    refine ⟨?_, ?_⟩
    · intro s h
      have := hend s h
      rw [hnothing s h] at this
      exact this.symm
    · intro past e future hse hk
      exact hrel past e future hse hk

/-! ## Fixtures — golden and forged corpora pinned at the theorem level -/

/-- A clean one-session mint→release→close. -/
theorem golden_clean :
    checkLog [
      "session-open\tt=100\tsession=br-1",
      "mint\tt=110\tsession=br-1\thandle=file_1\tverb=open\ttype=string\tsubject=path=\"a.txt\"",
      "release\tt=120\tsession=br-1\thandle=file_1\tby=close-file",
      "session-closed\tt=130\tsession=br-1"] = [] := by native_decide

/-- Two sessions, one world: disjoint spans each settle. -/
theorem golden_two_sessions :
    checkLog [
      "session-open\tt=1\tsession=a",
      "mint\tt=2\tsession=a\thandle=h1\tverb=open\ttype=string\tsubject=x=1",
      "release\tt=3\tsession=a\thandle=h1\tby=close",
      "session-closed\tt=4\tsession=a",
      "session-open\tt=5\tsession=b",
      "mint\tt=6\tsession=b\thandle=h2\tverb=open\ttype=string\tsubject=y=2",
      "release\tt=7\tsession=b\thandle=h2\tby=close",
      "session-closed\tt=8\tsession=b"] = [] := by native_decide

/-- A subject value may itself carry tabs — the tail rides verbatim. -/
theorem golden_subject_tab :
    checkLog [
      "session-open\tt=1\tsession=a",
      "mint\tt=2\tsession=a\thandle=h1\tverb=open\ttype=string\tsubject=x=a\tb",
      "release\tt=3\tsession=a\thandle=h1\tby=close",
      "session-closed\tt=4\tsession=a"] = [] := by native_decide

/-- Cross-session release of another span's handle: that handle was never
    minted in `b` — `release-of-unminted`, not silently legal. -/
theorem forged_cross_session_release :
    checkLog [
      "session-open\tt=1\tsession=a",
      "mint\tt=2\tsession=a\thandle=h1\tverb=open\ttype=string\tsubject=x=1",
      "release\tt=3\tsession=a\thandle=h1\tby=close",
      "session-closed\tt=4\tsession=a",
      "session-open\tt=5\tsession=b",
      "release\tt=6\tsession=b\thandle=h1\tby=close",
      "session-closed\tt=7\tsession=b"] =
      ["release-of-unminted: 'h1' in 'b' (line 6)"] := by native_decide

/-- A released handle released again is `double-release`, not
    `release-of-unminted` — the `dead` set is what distinguishes them. -/
theorem forged_double_release :
    checkLog [
      "session-open\tt=1\tsession=a",
      "mint\tt=2\tsession=a\thandle=h1\tverb=open\ttype=string\tsubject=x=1",
      "release\tt=3\tsession=a\thandle=h1\tby=close",
      "release\tt=4\tsession=a\thandle=h1\tby=close",
      "session-closed\tt=5\tsession=a"] =
      ["double-release: 'h1' in 'a' (line 4)"] := by native_decide

/-- A release with no mint anywhere. -/
theorem forged_unminted_release :
    checkLog [
      "session-open\tt=1\tsession=a",
      "release\tt=2\tsession=a\thandle=h9\tby=close",
      "session-closed\tt=3\tsession=a"] =
      ["release-of-unminted: 'h9' in 'a' (line 2)"] := by native_decide

/-- Session-closed while a mint is live: `dischargeAll` in `close`
    should have released it — the record dropped a release line. -/
theorem forged_unreleased_at_close :
    checkLog [
      "session-open\tt=1\tsession=a",
      "mint\tt=2\tsession=a\thandle=h1\tverb=open\ttype=string\tsubject=x=1",
      "session-closed\tt=3\tsession=a"] =
      ["unreleased-at-close: 'a' closed holding [h1] (line 3)"] := by
  native_decide

/-- A borrow exercises without settling: two `use` lines between mint and
    release leave the ledger clean. -/
theorem golden_use :
    checkLog [
      "session-open\tt=1\tsession=a",
      "mint\tt=2\tsession=a\thandle=conn_1\tverb=open\ttype=Conn\tsubject=path=\"f\"",
      "use\tt=3\tsession=a\thandle=conn_1\tverb=poke",
      "use\tt=4\tsession=a\thandle=conn_1\tverb=poke",
      "release\tt=5\tsession=a\thandle=conn_1\tby=close",
      "session-closed\tt=6\tsession=a"] = [] := by native_decide

/-- A use-after-release is the third leg of obligation safety: the
    `dead` set names it `use-of-released`, not `use-of-unminted`. -/
theorem forged_use_of_released :
    checkLog [
      "session-open\tt=1\tsession=a",
      "mint\tt=2\tsession=a\thandle=h1\tverb=open\ttype=string\tsubject=x=1",
      "release\tt=3\tsession=a\thandle=h1\tby=close",
      "use\tt=4\tsession=a\thandle=h1\tverb=poke",
      "session-closed\tt=5\tsession=a"] =
      ["use-of-released: 'h1' in 'a' (line 4)"] := by native_decide

/-- A use naming a handle that was never minted in that session. -/
theorem forged_use_of_unminted :
    checkLog [
      "session-open\tt=1\tsession=a",
      "use\tt=2\tsession=a\thandle=h9\tverb=poke",
      "session-closed\tt=3\tsession=a"] =
      ["use-of-unminted: 'h9' in 'a' (line 2)"] := by native_decide

/-- A use inside no span at all — and one after the span closed — is
    `use-outside-session`, the same family mint/release name. -/
theorem forged_use_outside_session :
    checkLog [
      "use\tt=1\tsession=a\thandle=h1\tverb=poke",
      "session-open\tt=2\tsession=a",
      "session-closed\tt=3\tsession=a",
      "use\tt=4\tsession=a\thandle=h1\tverb=poke"] =
      ["use-outside-session: 'h1' in 'a' (line 1)",
       "use-outside-session: 'h1' in 'a' (line 4)"] := by native_decide

/-- Process died holding: open span, live handle, no close. -/
theorem forged_died_holding :
    checkLog [
      "session-open\tt=1\tsession=a",
      "mint\tt=2\tsession=a\thandle=h1\tverb=open\ttype=string\tsubject=x=1"] =
      ["died-holding: 'a' holding [h1]"] := by native_decide

/-- Open span, nothing held, no close. -/
theorem forged_unclosed_session :
    checkLog [
      "session-open\tt=1\tsession=a",
      "mint\tt=2\tsession=a\thandle=h1\tverb=open\ttype=string\tsubject=x=1",
      "release\tt=3\tsession=a\thandle=h1\tby=close"] =
      ["unclosed-session: 'a'"] := by native_decide

/-- A mint after the span ended. -/
theorem forged_mint_outside_session :
    checkLog [
      "session-open\tt=1\tsession=a",
      "session-closed\tt=2\tsession=a",
      "mint\tt=3\tsession=a\thandle=h1\tverb=open\ttype=string\tsubject=x=1"] =
      ["mint-outside-session: 'h1' in 'a' (line 3)"] := by native_decide

/-- The same session id opening twice without a close. -/
theorem forged_reopen :
    checkLog [
      "session-open\tt=1\tsession=a",
      "session-open\tt=2\tsession=a"] =
      ["reopen: session 'a' opened while open (line 2)",
       "unclosed-session: 'a'"] := by native_decide

/-- A close with no open. -/
theorem forged_close_of_unopened :
    checkLog ["session-closed\tt=1\tsession=a"] =
      ["close-of-unopened: 'a' (line 1)"] := by native_decide

/-- A line that is not a custody event — the checker owns the
    vocabulary, so a future `use` edge refuses until R2 lands it. -/
theorem forged_grammar :
    checkLog [
      "session-open\tt=1\tsession=a",
      "use\tt=2\tsession=a\thandle=h1\tby=read-file",
      "session-closed\tt=3\tsession=a"] =
      ["grammar: line 2 is not a custody event"] := by native_decide

/-! ## Role B entry point -/

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
    let lines := (← IO.FS.lines path).toList
    if lines.isEmpty then
      IO.println s!"FAIL: {path} is empty — a marked run wrote no custody events"
      return 1
    let vs := checkLog lines
    for v in vs do
      IO.println s!"BAD  {v}"
    if vs.isEmpty then
      IO.println s!"clean: {lines.length} events, ledger closed"
      return 0
    else
      IO.println s!"malformed: {vs.length} violation(s)"
      return 1
  | _ =>
    IO.eprintln "usage: lean --run HoldsCheck.lean <holds.log>"
    return 2

end Koru.HoldsCheck

/-- `lean --run` looks for a top-level `main`. -/
def main (args : List String) : IO UInt32 := Koru.HoldsCheck.main args
