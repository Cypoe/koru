/-
Claims ledger checker — the claims pass's committed verdicts, re-decided.

The writer is `compiler.claims.kz`: `pass-claims-check` judges every
`~std/spec:claim` site and, when the program declared
`std/witness:enforce`, commits one `[claim-check]` line per judged or
declared claim plus one trailing `[claim-census]` line — into stderr, so
a regression test's `backend.err` is the corpus. This checker decides
whether the record is a lawful claims ledger: the pass is the source of
truth, the lines are evidence, and evidence gets re-decided, not trusted
(N1: solver ≠ checker). The ledger's shape and completeness are
re-decided at accounting level, and the linear judgment itself is
re-decided from the committed FM pre-image.

Vocabulary — space-separated fields:

    [claim-check] site <file>:<line> <atom> on <subject> declared
    [claim-check] site <file>:<line> <atom> on <subject> proven — <detail>
    [claim-check] site <file>:<line> <atom> on <subject> unproven — <detail>
    [claim-check] site <file>:<line> <atom> on <subject> outside-P — <detail>
    [claim-term] site <file>:<line> cand=<k> rank=<parts> type=<rows>
    [claim-goal] site <file>:<line> goal=<lhs>~<op>~<rhs> type=<rows>
    [claim-head] site <file>:<line> fold=<i> rows=<rows>
    [claim-edge] site <file>:<line> cand=<k> fold=<f> edge=<i> arm=<arm> case=<c> rows=<rows> sub=<subs>
    [claim-census] claims=<n> declared=<d> proven=<p> unproven=<u> outside=<o> edges=<e>

Ledger rules:

    claim-check     `site` parses as <file>:<line> with the line a
                    natural (the file may itself carry `:` — the LAST
                    colon is the separator); the atom is a registered
                    claim atom (`terminates`, `honors` — spec's
                    vocabulary, pinned here: a new spec atom must grow
                    this list or every enforced claim fails the oracle);
                    the subject is nonempty; the verdict is one of the
                    four words. `declared` carries nothing after the
                    verdict; a judged verdict carries ` — <detail>` with
                    a non-empty detail — a verdict without its reason is
                    a verdict that can't be routed.
    claim-term      terminates evidence: the `rank` a candidate tried
                    and the declared `&`-type row set. One line per
                    candidate (declared claims commit cand=0; inferred
                    claims commit EVERY candidate tried — `unproven` is
                    re-decidable only because each is committed).
    claim-goal      honors evidence: the goal comparison + type rows.
    claim-head      honors base: the fold's entry-binding equality rows
                    (entry names spell `entry.<n>`; the pass's internal
                    `~entry.` prefix is mangled on the wire — the name is
                    opaque to FM either way).
    claim-edge      one back-edge case: `rows` = the arm's premise rows,
                    `sub` = `name=<parts>;…` the jump's rebinding.
    claim-census    exactly six `key=<nat>` fields in the fixed order.
                    Exactly ONE census line per corpus, and it is the
                    last vocabulary line — the pass emits it after the
                    claims loop, so a vocabulary line behind it is
                    splice drift.
    census honesty  `claims` equals the number of `[claim-check]` lines,
                    `edges` equals the number of `[claim-edge]` lines,
                    and each verdict field equals its emitted count —
                    a dropped or invented line unbalances the record.
    drift           two byte-identical `[claim-check]` lines are one
                    claim admitted twice — the site is unique per
                    spelling, so identity is splice evidence.
    anything else   a line starting `[claim-` that fits neither shape
                    is vocabulary-adjacent garbage — MALFORMED, not
                    skipped. Other lanes' lines (`[claim]`, `[witness]`,
                    …) are ignored.

Linear wire grammar: a row is `<terms>~<op>~<bound>` (op `<` or `<=` —
`<` is the strict marker FM tightens by one); a parts list is
`coef*name` / bare `coef` comma-joined, `-` for empty; a subs list is
`name=<parts>` joined by `;`, `-` for empty.

RE-DECISION (the semantic leg): the committed rows are the pre-image
the pass's Fourier–Motzkin engine consumed. The checker replays the
whole judgment after the arm-meet stage — re-substitutes, rebuilds the
meets (arm premise ∪ declared types ∪ substituted types), re-negates
the obligations, and re-decides integer-tightened FM under the same
fences (>64 rows in, >3 named vars, >256 derived rows). `proven` then
means the committed evidence really entails it — every edge-case's
obligations refute; `unproven` means every committed candidate has a
failing check. A forged `proven` now fails because its committed rows
cannot entail it — and a fabricated `unproven` fails the other way when
the evidence does entail. `declared`/`outside-P` carry no re-decidable
judgment; their evidence lines are parsed (malformed is still a
violation) but not re-run. The irreducible channel limit, honestly
stated: whether the committed rows mirror the program's actual arm
premises is asserted by the pass — the checker verifies
verdict-follows-evidence, not evidence-follows-AST.

Run (Role B):
    lean --run ClaimsCheck.lean <corpus>            — every line must match
    lean --run ClaimsCheck.lean --forged <corpus>   — every line must be REJECTED (N4)
-/

namespace Koru.ClaimsCheck

/-! #### Vocabulary and parsing -/

/-- The registered claim atoms, pinned from `spec.claims.kz`'s
`claim_atoms`. A spec-side addition that forgets to grow this list is
caught by the oracle — the vocabulary is spec's, the pin is the
checker's honest copy of it. -/
def registeredAtoms : List String := ["terminates", "honors"]

inductive Verdict where
  | declared | proven | unproven | outside
  deriving Repr, BEq, DecidableEq, Inhabited

def Verdict.text : Verdict → String
  | .declared => "declared"
  | .proven => "proven"
  | .unproven => "unproven"
  | .outside => "outside-P"

def readVerdict (s : String) : Option Verdict :=
  match s with
  | "declared" => some .declared
  | "proven" => some .proven
  | "unproven" => some .unproven
  | "outside-P" => some .outside
  | _ => none

structure ClaimLine where
  file : String
  line : Nat
  atom : String
  subject : String
  verdict : Verdict
  detail : String
  deriving Repr

/-- `site <file>:<line>` — split on the LAST colon so a file carrying
`:` keeps its name; the trailing field must be a natural. -/
def parseSite (s : String) : Option (String × Nat) :=
  let parts := s.splitOn ":"
  match parts.getLast? with
  | none => none
  | some last =>
    match last.toNat? with
    | none => none
    | some n =>
      let file := String.intercalate ":" (parts.take (parts.length - 1))
      if file.isEmpty then none else some (file, n)

/-- A census field `key=<nat>`; the key is fixed by position. -/
def readField (tok key : String) : Option Nat :=
  if tok.startsWith (key ++ "=") then
    (tok.drop (key.length + 1)).toNat?
  else none

inductive Ruling where
  | match_ | malformed
  deriving Repr, BEq, DecidableEq

/-- One `[claim-check]` line's ruling: shape, site, atom, subject,
verdict, and the detail discipline — judged lines must carry ` — `
plus a non-empty detail; `declared` carries nothing. -/
def ruleClaim (toks : List String) : Ruling :=
  match toks with
  | "[claim-check]" :: "site" :: siteTok :: atom :: "on" :: subject :: verdictTok :: rest =>
    match parseSite siteTok with
    | none => .malformed
    | some _ =>
      if !(registeredAtoms.contains atom) then .malformed
      else if subject.isEmpty then .malformed
      else match readVerdict verdictTok with
        | none => .malformed
        | some .declared =>
          if rest.isEmpty then .match_ else .malformed
        | some _ =>
          match rest with
          | "—" :: detailToks =>
            if detailToks.isEmpty then .malformed else .match_
          | _ => .malformed
  | _ => .malformed

/-- One `[claim-census]` line's ruling: exactly the six fields in
fixed order, each `<key>=<nat>`. -/
def ruleCensus (toks : List String) : Option (Nat × Nat × Nat × Nat × Nat × Nat) :=
  match toks with
  | ["[claim-census]", c, d, p, u, o, e] =>
    match readField c "claims", readField d "declared", readField p "proven",
          readField u "unproven", readField o "outside", readField e "edges" with
    | some cn, some dn, some pn, some un, some on, some en => some (cn, dn, pn, un, on, en)
    | _, _, _, _, _, _ => none
  | _ => none

/-! #### Evidence lines — the committed FM pre-image -/

/-- `Σ coef·name <= bound`; `strict` is the `<` marker, tightened to
`bound - 1` when the row enters the engine. -/
structure LinRow where
  terms : List (Int × String)
  bound : Int
  strict : Bool
deriving DecidableEq

/-- A rebinding `name ↦ linear expr` — jump args under the claims
fence are exactly these. -/
structure LinSub where
  name : String
  expr : List (Int × Option String)
deriving DecidableEq

structure TermLine where
  cand : Nat
  rank : List (Int × Option String)
  typeRows : List LinRow
deriving DecidableEq

structure GoalLine where
  lhs : List (Int × Option String)
  op : String
  rhs : List (Int × Option String)
  typeRows : List LinRow
deriving Inhabited, DecidableEq

structure HeadLine where
  fold : Nat
  rows : List LinRow
deriving DecidableEq

structure EdgeLine where
  cand : Nat
  fold : Nat
  edge : Nat
  arm : String
  case_ : Nat
  rows : List LinRow
  subs : List LinSub
deriving Inhabited, DecidableEq

/-- `<coef>*<name>` or a bare `<coef>` — the strict wire spelling
(`-` spells the empty list at the list level, never a part). -/
def wirePart (s : String) : Option (Int × Option String) :=
  match s.splitOn "*" with
  | [c, n] => match c.toInt? with
    | some ci => if n.isEmpty then none else some (ci, some n)
    | none => none
  | [t] => match t.toInt? with
    | some ci => some (ci, none)
    | none => none
  | _ => none

def wireParts (s : String) : Option (List (Int × Option String)) :=
  if s = "-" then some [] else (s.splitOn ",").mapM wirePart

/-- `<terms>~<op>~<bound>`; `-` on the terms side spells no terms. -/
def wireRow (s : String) : Option LinRow :=
  match s.splitOn "~" with
  | [l, o, b] => do
    let parts ← wireParts l
    let mut terms : List (Int × String) := []
    for (c, n) in parts do
      match n with
      | some nm => terms := terms ++ [(c, nm)]
      | none => failure
    let bound ← b.toInt?
    match o with
    | "<" => some ⟨terms, bound, true⟩
    | "<=" => some ⟨terms, bound, false⟩
    | _ => none
  | _ => none

def wireRows (s : String) : Option (List LinRow) :=
  if s = "-" then some [] else (s.splitOn "|").mapM wireRow

def wireSubs (s : String) : Option (List LinSub) :=
  if s = "-" then some [] else
    (s.splitOn ";").mapM fun e =>
      match e.splitOn "=" with
      | [n, p] => do
        let pe ← wireParts p
        some ⟨n, pe⟩
      | _ => none

/-- `[claim-term] site <s> cand=<k> rank=<parts> type=<rows>` -/
def parseTermLine (toks : List String) : Option (String × TermLine) :=
  match toks with
  | ["[claim-term]", "site", site, candT, rankT, typeT] => do
    let cand ← readField candT "cand"
    let rank ← if rankT.startsWith "rank=" then wireParts (rankT.drop 5).toString else none
    let typeRows ← if typeT.startsWith "type=" then wireRows (typeT.drop 5).toString else none
    some (site, ⟨cand, rank, typeRows⟩)
  | _ => none

/-- `[claim-goal] site <s> goal=<lhs>~<op>~<rhs> type=<rows>` -/
def parseGoalLine (toks : List String) : Option (String × GoalLine) :=
  match toks with
  | ["[claim-goal]", "site", site, goalT, typeT] => do
    if !goalT.startsWith "goal=" then none
    match (goalT.drop 5).toString.splitOn "~" with
    | [l, o, r] => do
      let lhs ← wireParts l
      let rhs ← wireParts r
      if !(["<=", "<", ">=", ">", "==", "!="].contains o) then none
      let typeRows ← if typeT.startsWith "type=" then wireRows (typeT.drop 5).toString else none
      some (site, ⟨lhs, o, rhs, typeRows⟩)
    | _ => none
  | _ => none

/-- `[claim-head] site <s> fold=<i> rows=<rows>` -/
def parseHeadLine (toks : List String) : Option (String × HeadLine) :=
  match toks with
  | ["[claim-head]", "site", site, foldT, rowsT] => do
    let fold ← readField foldT "fold"
    let rows ← if rowsT.startsWith "rows=" then wireRows (rowsT.drop 5).toString else none
    some (site, ⟨fold, rows⟩)
  | _ => none

/-- `[claim-edge] site <s> cand=<k> fold=<f> edge=<i> arm=<a> case=<c> rows=<r> sub=<s>` -/
def parseEdgeLine (toks : List String) : Option (String × EdgeLine) :=
  match toks with
  | ["[claim-edge]", "site", site, candT, foldT, edgeT, armT, caseT, rowsT, subT] => do
    let cand ← readField candT "cand"
    let fold ← readField foldT "fold"
    let edge ← readField edgeT "edge"
    let arm ← if armT.startsWith "arm=" then some (armT.drop 4).toString else none
    let case_ ← readField caseT "case"
    let rows ← if rowsT.startsWith "rows=" then wireRows (rowsT.drop 5).toString else none
    let subs ← if subT.startsWith "sub=" then wireSubs (subT.drop 4).toString else none
    some (site, ⟨cand, fold, edge, arm, case_, rows, subs⟩)
  | _ => none

/-- Vocabulary membership: only `[claim-`-prefixed lines are ours. -/
def isClaimLine (line : String) : Bool := line.startsWith "[claim-"

/-! #### The linear engine — spec.linear.kz, re-decided

A faithful port of `spec.linear.kz`: the same canonicalization, the
same substitution, the same integer-tightened Fourier–Motzkin with the
same fences. `outside` is the engine's own fence verdict — hitting it
is a ledger violation (the corpus asked the checker to decide something
undecidable). -/

/-- spec.linSubstitute: replace each named part by its sub expression,
unbound names ride through. -/
def linSubstitute (form : List (Int × Option String)) (subs : List LinSub) :
    List (Int × Option String) :=
  form.flatMap fun (c, n) =>
    match n with
    | none => [(c, none)]
    | some nm =>
      match subs.find? (·.name == nm) with
      | some s => s.expr.map fun (ec, en) => (c * ec, en)
      | none => [(c, n)]

/-- spec.linNormalize: `lhs <= rhs` → terms `lhs − rhs` sorted by name
and merged (zeros dropped), bound `rhs.const − lhs.const`. -/
def linNormalize (lhs rhs : List (Int × Option String)) (strict : Bool) : LinRow :=
  let raw := lhs.filterMap (fun (c, n) => n.map (c, ·)) ++
             rhs.filterMap (fun (c, n) => n.map (-c, ·))
  let sorted := raw.mergeSort fun a b =>
    match String.compare a.2 b.2 with | .lt | .eq => true | .gt => false
  let merged := sorted.foldl (init := ([] : List (Int × String))) fun acc (c, n) =>
    match acc with
    | (c', n') :: rest =>
      if n' == n then (c' + c, n') :: rest else (c, n) :: acc
    | [] => [(c, n)]
  let const (ps : List (Int × Option String)) :=
    ps.foldl (init := (0 : Int)) fun a (c, n) => if n.isNone then a + c else a
  ⟨merged.reverse.filter (·.1 != 0), const rhs - const lhs, strict⟩

/-- spec.claimsGuardRows: a comparison as rows; `negate` answers the
else-arm's set. `==` gives both directions when positive, nothing when
negated (≠ is not one row); `!=` mirrors. -/
def guardRows (lhs rhs : List (Int × Option String)) (op : String)
    (negate : Bool) : List LinRow := Id.run do
  let ln := fun (l r : List (Int × Option String)) (s : Bool) => linNormalize l r s
  let mut rows : List LinRow := []
  if !negate then
    if op = "<" then rows := rows ++ [ln lhs rhs true]
    if op = "<=" then rows := rows ++ [ln lhs rhs false]
    if op = ">" then rows := rows ++ [ln rhs lhs true]
    if op = ">=" then rows := rows ++ [ln rhs lhs false]
    if op = "==" then rows := rows ++ [ln lhs rhs false, ln rhs lhs false]
  else
    if op = "<" then rows := rows ++ [ln rhs lhs false]
    if op = "<=" then rows := rows ++ [ln rhs lhs true]
    if op = ">" then rows := rows ++ [ln lhs rhs false]
    if op = ">=" then rows := rows ++ [ln lhs rhs true]
    if op = "!=" then rows := rows ++ [ln lhs rhs false, ln rhs lhs false]
  return rows

/-- spec.claimsSubRows: the declared-type rows under a rebinding —
`i & >=0` read under `i' = i − 1` is `i − 1 >= 0`. -/
def subRows (rows : List LinRow) (subs : List LinSub) : List LinRow :=
  rows.map fun r =>
    let parts := r.terms.map (fun (c, n) => (c, some n)) ++ [(-r.bound, none)]
    let subbed := linSubstitute parts subs
    let const := subbed.foldl (init := (0 : Int)) fun a (c, n) =>
      if n.isNone then a + c else a
    let named := subbed.filterMap fun (c, n) => n.map (c, ·)
    ⟨named, -const, r.strict⟩

inductive Feas where | feasible | infeasible | outside
  deriving Repr, BEq, DecidableEq

/-- spec.linFeasible: integer-exact Fourier–Motzkin. Fences: >64 input
rows, >3 named vars, >256 derived rows → `outside`. Strict rows tighten
at load (`bound - 1`); a constant row with `bound < 0` is the
refutation. Variable elimination order is first-seen across the row
set — order changes neither the verdict (FM is real-complete) nor the
integer gaps the fence documents. -/
def linFeasible (orig : List LinRow) : Feas := Id.run do
  if orig.isEmpty then return .feasible
  if orig.length > 64 then return .outside
  let mut names : List String := []
  for r in orig do
    for t in r.terms do
      if !names.contains t.2 then names := names ++ [t.2]
  if names.length > 3 then return .outside
  let mut w : List LinRow := orig.map fun r =>
    ⟨r.terms, r.bound - (if r.strict then 1 else 0), false⟩
  for v in names do
    let coef := fun (r : LinRow) =>
      (r.terms.find? (·.2 == v)).map (·.1) |>.getD 0
    let mut next : List LinRow := []
    for r in w do
      if coef r = 0 then next := next ++ [r]
    for n in w do
      let nc := coef n
      if nc < 0 then
        for p in w do
          let pc := coef p
          if pc > 0 then
            let a := -nc
            let b := pc
            let terms := (n.terms.filter (·.2 != v)).map (fun (c, nm) => (c * b, nm))
            let merged := (p.terms.filter (·.2 != v)).foldl (init := terms)
              fun acc (c, nm) =>
                match acc.findIdx? (·.2 == nm) with
                | some i => acc.modify i fun (c', m) => (c' + c * a, m)
                | none => acc ++ [(c * a, nm)]
            next := next ++ [⟨merged.filter (·.1 != 0), n.bound * b + p.bound * a,
              n.strict || p.strict⟩]
    if next.length > 256 then return .outside
    w := next
  for r in w do
    if r.terms.isEmpty && r.bound < 0 then return .infeasible
  return .feasible

/-- spec.claimsEntail: `meet ⊢ lhs <op> rhs` iff `meet ∧ ¬(lhs <op> rhs)`
is empty; `==` needs both directions. -/
inductive Entail where | entailed | open | outside
  deriving Repr, BEq, DecidableEq

def entail (meet : List LinRow) (lhs : List (Int × Option String))
    (op : String) (rhs : List (Int × Option String)) : Entail := Id.run do
  let dirs := if op = "==" then ["<=", ">="] else [op]
  for d in dirs do
    let neg := guardRows lhs rhs d true
    if neg.isEmpty then return .outside
    match linFeasible (meet ++ neg) with
    | .infeasible => continue
    | .feasible => return .open
    | .outside => return .outside
  return .entailed

/-! #### The re-decision -/

inductive CheckOut where | pass | fail | outside
  deriving Repr, BEq, DecidableEq

/-- One terminates edge-case, re-decided: the two refutations the pass
ran — `meet ∧ (R − R' ≤ 0)` and `meet ∧ (R' < 0)` must both be empty. -/
def redecideTermEdge (typeRows : List LinRow) (rank : List (Int × Option String))
    (e : EdgeLine) : CheckOut :=
  let subType := subRows typeRows e.subs
  let meet := e.rows ++ typeRows ++ subType
  let next := linSubstitute rank e.subs
  let diff := rank ++ next.map fun (c, n) => (-c, n)
  match linFeasible (meet ++ [linNormalize diff [] false]),
        linFeasible (meet ++ [linNormalize next [] true]) with
  | .infeasible, .infeasible => .pass
  | .feasible, _ | _, .feasible => .fail
  | _, _ => .outside

/-- One honors edge-case, re-decided: `IH ∧ case ∧ types ⊢ goal'`. -/
def redecideHonorsEdge (typeRows : List LinRow) (ih : List LinRow) (op : String)
    (lhs rhs : List (Int × Option String)) (e : EdgeLine) : CheckOut :=
  let subType := subRows typeRows e.subs
  let meet := ih ++ e.rows ++ typeRows ++ subType
  match entail meet (linSubstitute lhs e.subs) op (linSubstitute rhs e.subs) with
  | .entailed => .pass
  | .open => .fail
  | .outside => .outside

/-- The honors base: `entry ∪ types ⊢ goal`. -/
def redecideHonorsHead (typeRows : List LinRow) (h : HeadLine)
    (lhs : List (Int × Option String)) (op : String)
    (rhs : List (Int × Option String)) : CheckOut :=
  match entail (h.rows ++ typeRows) lhs op rhs with
  | .entailed => .pass
  | .open => .fail
  | .outside => .outside

/-- The emitted census, counted over the committed lines — never the
printed one trusted. -/
def countVerdicts (verdicts : List Verdict) : Nat × Nat × Nat × Nat :=
  verdicts.foldl (init := (0, 0, 0, 0)) fun (d, p, u, o) v =>
    match v with
    | .declared => (d + 1, p, u, o)
    | .proven => (d, p + 1, u, o)
    | .unproven => (d, p, u + 1, o)
    | .outside => (d, p, u, o + 1)

/-- The verdict one claim site's committed evidence supports —
recomputed, never trusted from the `[claim-check]` line. -/
def redecideTermSite (terms : List TermLine) (edges : List EdgeLine) :
    CheckOut × Option Nat := Id.run do
  for t in terms do
    let mine := edges.filter (·.cand == t.cand)
    let mut ok := true
    for e in mine do
      match redecideTermEdge t.typeRows t.rank e with
      | .pass => continue
      | .fail => ok := false
      | .outside => return ⟨.outside, some t.cand⟩
    if ok then return ⟨.pass, some t.cand⟩
  return ⟨.fail, none⟩

/-- One honors site's committed checks, replayed: `IH ∧ case ∧ types ⊢ goal'`
per edge plus `entry ∪ types ⊢ goal` per head. Returns (fails, fence-outs). -/
def redecideHonorsSite (g : GoalLine) (heads : List HeadLine)
    (edges : List EdgeLine) : Nat × Nat := Id.run do
  let ih := guardRows g.lhs g.rhs g.op false
  let mut fails := 0
  let mut offs := 0
  for h in heads do
    match redecideHonorsHead g.typeRows h g.lhs g.op g.rhs with
    | .pass => ()
    | .fail => fails := fails + 1
    | .outside => offs := offs + 1
  for e in edges do
    match redecideHonorsEdge g.typeRows ih g.op g.lhs g.rhs e with
    | .pass => ()
    | .fail => fails := fails + 1
    | .outside => offs := offs + 1
  return (fails, offs)

/-- Semantic re-decision of judged claims. `declared`/`outside-P` carry
no re-decidable verdict — their evidence lines parse but are not run.
`proven`/`unproven` are re-decided from the committed FM pre-image. -/
def semanticViolations
    (claims : List (String × String × Verdict))
    (terms : List (String × TermLine)) (goals : List (String × GoalLine))
    (heads : List (String × HeadLine)) (edges : List (String × EdgeLine)) :
    List String := Id.run do
  let mut out : List String := []
  -- Evidence must answer to a claim site, and to its own atom.
  for (site, _) in terms do
    if !(claims.any (·.1 == site)) then out := out ++ [s!"orphan [claim-term] at {site}"]
  for (site, _) in goals do
    if !(claims.any (·.1 == site)) then out := out ++ [s!"orphan [claim-goal] at {site}"]
  for (site, _) in heads do
    if !(claims.any (·.1 == site)) then out := out ++ [s!"orphan [claim-head] at {site}"]
  for (site, _) in edges do
    if !(claims.any (·.1 == site)) then out := out ++ [s!"orphan [claim-edge] at {site}"]
  for (site, atom, verdict) in claims do
    let sTerms := (terms.filter (·.1 == site)).map (·.2)
    let sGoals := (goals.filter (·.1 == site)).map (·.2)
    let sHeads := (heads.filter (·.1 == site)).map (·.2)
    let sEdges := (edges.filter (·.1 == site)).map (·.2)
    if !sTerms.isEmpty && atom != "terminates" then
      out := out ++ [s!"[claim-term] under a {atom} claim at {site}"]
    if !sGoals.isEmpty && atom != "honors" then
      out := out ++ [s!"[claim-goal] under a {atom} claim at {site}"]
    if !sHeads.isEmpty && atom != "honors" then
      out := out ++ [s!"[claim-head] under a {atom} claim at {site}"]
    if atom == "terminates" then
      match verdict with
      | .proven =>
        if sTerms.isEmpty then
          out := out ++ [s!"verdict 'proven' at {site} carries no committed rank evidence"]
        else
          match redecideTermSite sTerms sEdges with
          | (.pass, _) => ()
          | (.fail, _) =>
            out := out ++ [s!"verdict 'proven' at {site} but the committed evidence does not discharge any candidate"]
          | (.outside, _) =>
            out := out ++ [s!"edge re-decision at {site} exceeds the decidable fence"]
      | .unproven =>
        if !sTerms.isEmpty then
          match redecideTermSite sTerms sEdges with
          | (.pass, some c) =>
            out := out ++ [s!"verdict 'unproven' at {site} but committed candidate {c} discharges every edge"]
          | (.pass, none) => ()
          | (.fail, _) => ()
          | (.outside, _) =>
            out := out ++ [s!"edge re-decision at {site} exceeds the decidable fence"]
      | _ => ()
    if atom == "honors" then
      match verdict with
      | .proven =>
        match sGoals with
        | [] =>
          out := out ++ [s!"verdict 'proven' at {site} carries no committed goal evidence"]
        | g :: _ =>
          let (fails, offs) := redecideHonorsSite g sHeads sEdges
          if offs > 0 then
            out := out ++ [s!"honors re-decision at {site} exceeds the decidable fence"]
          else if fails > 0 then
            out := out ++ [s!"verdict 'proven' at {site} but {fails} committed checks leave the goal open"]
      | .unproven =>
        match sGoals with
        | [] => ()
        | g :: _ =>
          let (fails, offs) := redecideHonorsSite g sHeads sEdges
          if offs > 0 then
            out := out ++ [s!"honors re-decision at {site} exceeds the decidable fence"]
          else if fails == 0 then
            out := out ++ [s!"verdict 'unproven' at {site} but every committed check discharges the goal"]
      | _ => ()
  return out

/-- Corpus checks over the accepted lines. Returns violation strings —
each fails a conformance batch and is one more reason a forged batch
can't pass. -/
def corpusViolations
    (claimLines : List String) (parsed : List ClaimLine)
    (censuses : List (Nat × Nat × Nat × Nat × Nat × Nat)) (edgeCount : Nat)
    (censusPositions : List Nat) (lastIdx : Nat) : List String := Id.run do
  let mut out : List String := []
  -- exactly one census, and it is the last vocabulary line
  if censuses.isEmpty then out := out ++ ["missing [claim-census]"]
  if censuses.length > 1 then out := out ++ [s!"{censuses.length} [claim-census] lines — exactly one committed"]
  for pos in censusPositions do
    if pos != lastIdx then out := out ++ ["[claim-census] is not the last vocabulary line"]
  -- census honesty
  for (cn, dn, pn, un, on, en) in censuses do
    let (d, p, u, o) := countVerdicts (parsed.map (·.verdict))
    if cn != parsed.length then
      out := out ++ [s!"census claims={cn} but {parsed.length} [claim-check] lines emitted"]
    if dn != d then out := out ++ [s!"census declared={dn} but {d} emitted"]
    if pn != p then out := out ++ [s!"census proven={pn} but {p} emitted"]
    if un != u then out := out ++ [s!"census unproven={un} but {u} emitted"]
    if on != o then out := out ++ [s!"census outside={on} but {o} emitted"]
    if en != edgeCount then
      out := out ++ [s!"census edges={en} but {edgeCount} [claim-edge] lines emitted"]
  -- drift: a line admitted twice
  let mut seen : List String := []
  for l in claimLines do
    if seen.contains l then out := out ++ [s!"duplicate: {l}"] else seen := l :: seen
  return out

/-! #### Role A pins — the relations' fixture classes, decided at
compile time -/

-- judged verdicts carry ` — <detail>`; declared carries nothing
example : ruleClaim ("[claim-check] site input.kz:11 terminates on step proven — rank decreases".splitOn " ") = .match_ := by native_decide
example : ruleClaim ("[claim-check] site input.kz:11 terminates on step declared".splitOn " ") = .match_ := by native_decide
example : ruleClaim ("[claim-check] site input.kz:11 honors on step unproven — the meet leaves it open".splitOn " ") = .match_ := by native_decide
example : ruleClaim ("[claim-check] site input.kz:11 terminates on step outside-P — the impl is not a fold".splitOn " ") = .match_ := by native_decide
-- a judged verdict without its reason cannot be routed
example : ruleClaim ("[claim-check] site input.kz:11 terminates on step proven".splitOn " ") = .malformed := by native_decide
example : ruleClaim ("[claim-check] site input.kz:11 terminates on step proven —".splitOn " ") = .malformed := by native_decide
-- a declared claim carrying a verdict's detail is two records spliced
example : ruleClaim ("[claim-check] site input.kz:11 terminates on step declared — rank i".splitOn " ") = .malformed := by native_decide
-- an atom spec never registered is not a claim
example : ruleClaim ("[claim-check] site input.kz:11 halts on step proven — fabricated".splitOn " ") = .malformed := by native_decide
-- a verdict outside the four words is not a verdict
example : ruleClaim ("[claim-check] site input.kz:11 terminates on step probably — fabricated".splitOn " ") = .malformed := by native_decide
-- the site must carry a line number and a file
example : ruleClaim ("[claim-check] site input.kz terminates on step declared".splitOn " ") = .malformed := by native_decide
example : ruleClaim ("[claim-check] site :11 terminates on step declared".splitOn " ") = .malformed := by native_decide
example : ruleClaim ("[claim-check] site input.kz:x terminates on step declared".splitOn " ") = .malformed := by native_decide
-- vocabulary-adjacent shapes are malformed, not skipped
example : ruleClaim ("[claim-check] site input.kz:11 terminates declared".splitOn " ") = .malformed := by native_decide
example : ruleClaim ("[claim] site input.kz:11 terminates on step declared".splitOn " ") = .malformed := by native_decide
-- census: the six fields in fixed order, each a nat
example : ruleCensus ("[claim-census] claims=3 declared=1 proven=1 unproven=1 outside=0 edges=4".splitOn " ") = some (3, 1, 1, 1, 0, 4) := by native_decide
example : ruleCensus ("[claim-census] claims=3 proven=1 declared=1 unproven=1 outside=0 edges=4".splitOn " ") = none := by native_decide
example : ruleCensus ("[claim-census] claims=3 declared=1 proven=1 unproven=1 outside=0".splitOn " ") = none := by native_decide
example : ruleCensus ("[claim-census] claims=x declared=1 proven=1 unproven=1 outside=0 edges=4".splitOn " ") = none := by native_decide
-- evidence lines parse strictly
example : wireRow "1*i,-1*limit~<~0" = some ⟨[(1, "i"), (-1, "limit")], 0, true⟩ := by native_decide
example : wireParts "1*limit,-1*i" = some [(1, some "limit"), (-1, some "i")] := by native_decide
example : wireParts "-" = some [] := by native_decide
example : wireSubs "i=1*i,1;limit=1*limit" = some [⟨"i", [(1, some "i"), (1, none)]⟩, ⟨"limit", [(1, some "limit")]⟩] := by native_decide
example : wireRow "1*i~<=~3" = some ⟨[(1, "i")], 3, false⟩ := by native_decide
example : wireRow "1*i~>=~3" = none := by native_decide
-- the engine, re-decided: substitution, negation, integer tightening
example : linSubstitute [(1, some "limit"), (-1, some "i")] [⟨"i", [(1, some "i"), (1, none)]⟩] =
    [(1, some "limit"), (-1, some "i"), (-1, none)] := by native_decide
-- limit−i−1 < 0 is refuted by i − limit ≤ −1: the tightened meet is empty
example : linFeasible [⟨[(1, "i"), (-1, "limit")], -1, false⟩,
    ⟨[(1, "limit"), (-1, "i")], -2, true⟩] = .infeasible := by native_decide
-- over real bounds an integer-tightened strict gap still reads feasible
example : linFeasible [⟨[(2, "x")], 1, false⟩, ⟨[(-2, "x")], -1, false⟩] = .feasible := by native_decide
example : linFeasible [⟨[(1, "x")], 0, true⟩, ⟨[(-1, "x")], 0, false⟩] = .infeasible := by native_decide
-- entail: meet ∪ ¬goal is the refutation
example : entail [⟨[(1, "i"), (-1, "limit")], -1, false⟩] [(1, some "i")] "<=" [(1, some "limit")] = .entailed := by native_decide
example : entail [] [(1, some "i")] "<=" [(-1, some "limit")] = .open := by native_decide
-- the site parser takes the LAST colon — a qualified file keeps its name
example : parseSite "a:b/input.kz:11" = some ("a:b/input.kz", 11) := by native_decide
example : parseSite "input.kz:0" = some ("input.kz", 0) := by native_decide

/-- Role A: the emitter's verdict word and the checker's are the same
vocabulary — `readVerdict` is the only admission channel, and it
round-trips every word the pass can print. -/
theorem readVerdict_roundtrip (v : Verdict) : readVerdict v.text = some v := by
  cases v <;> native_decide

/-- Role A: an accepted line carries the full emitted shape — at least
the seven fixed fields the grammar demands before any detail. -/
theorem accepted_length (toks : List String) (hr : ruleClaim toks = .match_) :
    toks.length ≥ 7 := by
  unfold ruleClaim at hr
  split at hr
  · simp only [List.length_cons]; omega
  · simp at hr

/-! #### Role B — the run -/

def parseArgs : List String → Option (Bool × String)
  | ["--forged", p] => some (true, p)
  | [p] => some (false, p)
  | _ => none

def main (args : List String) : IO UInt32 := do
  let some (forged, path) := parseArgs args
    | do IO.eprintln "usage: ClaimsCheck [--forged] <corpus>"; return 2
  let lines := (← IO.FS.lines path).toList.filter isClaimLine
  if lines.isEmpty then
    IO.println s!"FAIL: no [claim-*] lines in {path}"
    return 1
  let mut bad := 0
  let mut parsed : List ClaimLine := []
  let mut claimLines : List String := []
  let mut terms : List (String × TermLine) := []
  let mut goals : List (String × GoalLine) := []
  let mut heads : List (String × HeadLine) := []
  let mut edges : List (String × EdgeLine) := []
  let mut censuses : List (Nat × Nat × Nat × Nat × Nat × Nat) := []
  let mut censusPositions : List Nat := []
  let mut idx : Nat := 0
  for line in lines do
    let toks := line.splitOn " "
    let isCensus := line.startsWith "[claim-census]"
    let isCheck := line.startsWith "[claim-check]"
    let mut ruling : Ruling := .malformed
    if isCensus then
      match ruleCensus toks with
      | some c =>
        censuses := c :: censuses
        censusPositions := idx :: censusPositions
        ruling := .match_
      | none => ruling := .malformed
    else if isCheck then
      match ruleClaim toks with
      | .match_ =>
        if let some (file, ln) := parseSite toks[2]! then
          if let some v := readVerdict toks[6]! then
            parsed := ⟨file, ln, toks[3]!, toks[5]!, v,
              String.intercalate " " (toks.drop 8)⟩ :: parsed
        claimLines := line :: claimLines
        ruling := .match_
      | .malformed => ruling := .malformed
    else if line.startsWith "[claim-term]" then
      match parseTermLine toks with
      | some t => terms := t :: terms; ruling := .match_
      | none => ruling := .malformed
    else if line.startsWith "[claim-goal]" then
      match parseGoalLine toks with
      | some g => goals := g :: goals; ruling := .match_
      | none => ruling := .malformed
    else if line.startsWith "[claim-head]" then
      match parseHeadLine toks with
      | some h => heads := h :: heads; ruling := .match_
      | none => ruling := .malformed
    else if line.startsWith "[claim-edge]" then
      match parseEdgeLine toks with
      | some e => edges := e :: edges; ruling := .match_
      | none => ruling := .malformed
    idx := idx + 1
    let accepted := ruling == .match_
    let label := if accepted then "MATCH" else "MALFORMED"
    -- In --forged mode every line must be rejected; otherwise every line must match.
    let ok := if forged then !accepted else accepted
    if !ok then bad := bad + 1
    IO.println s!"{if ok then "ok  " else "BAD "} {label}  {line}"
  -- Corpus-level ledger laws: a corpus violation is rejection evidence —
  -- it fails a conformance batch, and in forged mode it is one more
  -- reason the batch can't pass.
  let lastIdx := if lines.isEmpty then 0 else lines.length - 1
  let claimSites := parsed.reverse.map fun cl =>
    (s!"{cl.file}:{cl.line}", cl.atom, cl.verdict)
  for v in corpusViolations claimLines.reverse parsed.reverse censuses edges.length censusPositions lastIdx do
    if !forged then bad := bad + 1
    IO.println s!"{if forged then "ok  " else "BAD "} LEDGER-VIOLATION  {v}"
  for v in semanticViolations claimSites terms.reverse goals.reverse heads.reverse edges.reverse do
    if !forged then bad := bad + 1
    IO.println s!"{if forged then "ok  " else "BAD "} LEDGER-VIOLATION  {v}"
  let mode := if forged then "forged (all must reject)" else "conformance (all must match)"
  IO.println s!"{mode}: {lines.length} lines, {bad} bad"
  return (if bad == 0 then 0 else 1)

end Koru.ClaimsCheck

def main (args : List String) : IO UInt32 := Koru.ClaimsCheck.main args
