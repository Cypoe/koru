/-
Claims ledger checker — the claims pass's committed verdicts, re-decided.

The writer is `compiler.claims.kz`: `pass-claims-check` judges every
`~std/spec:claim` site and, when the program declared
`std/witness:enforce`, commits one `[claim-check]` line per judged or
declared claim plus one trailing `[claim-census]` line — into stderr, so
a regression test's `backend.err` is the corpus. This checker decides
whether the record is a lawful claims ledger: the pass is the source of
truth, the lines are evidence, and evidence gets re-decided, not trusted
(N1: solver ≠ checker). This is the accounting level — the verdict's
SHAPE and the ledger's completeness are re-decided; the linear
entailment behind `proven`/`unproven` is not (yet).

Vocabulary — two line shapes, space-separated fields:

    [claim-check] site <file>:<line> <atom> on <subject> declared
    [claim-check] site <file>:<line> <atom> on <subject> proven — <detail>
    [claim-check] site <file>:<line> <atom> on <subject> unproven — <detail>
    [claim-check] site <file>:<line> <atom> on <subject> outside-P — <detail>
    [claim-census] claims=<n> declared=<d> proven=<p> unproven=<u> outside=<o>

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
    claim-census    exactly five `key=<nat>` fields in the fixed order.
                    Exactly ONE census line per corpus, and it is the
                    last vocabulary line — the pass emits it after the
                    claims loop, so a vocabulary line behind it is
                    splice drift.
    census honesty  `claims` equals the number of `[claim-check]` lines
                    and each verdict field equals its emitted count —
                    a dropped or invented line unbalances the record.
    drift           two byte-identical `[claim-check]` lines are one
                    claim admitted twice — the site is unique per
                    spelling, so identity is splice evidence.
    anything else   a line starting `[claim-` that fits neither shape
                    is vocabulary-adjacent garbage — MALFORMED, not
                    skipped. Other lanes' lines (`[claim]`, `[witness]`,
                    …) are ignored.

Channel limit, honestly stated: a forged `proven` whose shape is
well-formed passes THIS checker — semantic re-decision of the linear
judgment is the next leg, and it is a leg, not a patch on this one.

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

/-- One `[claim-census]` line's ruling: exactly the five fields in
fixed order, each `<key>=<nat>`. -/
def ruleCensus (toks : List String) : Option (Nat × Nat × Nat × Nat × Nat) :=
  match toks with
  | ["[claim-census]", c, d, p, u, o] =>
    match readField c "claims", readField d "declared", readField p "proven",
          readField u "unproven", readField o "outside" with
    | some cn, some dn, some pn, some un, some on => some (cn, dn, pn, un, on)
    | _, _, _, _, _ => none
  | _ => none

/-- Vocabulary membership: only `[claim-`-prefixed lines are ours. -/
def isClaimLine (line : String) : Bool := line.startsWith "[claim-"

/-! #### Corpus-level checks -/

/-- The emitted census, counted over the committed lines — never the
printed one trusted. -/
def countVerdicts (verdicts : List Verdict) : Nat × Nat × Nat × Nat :=
  verdicts.foldl (init := (0, 0, 0, 0)) fun (d, p, u, o) v =>
    match v with
    | .declared => (d + 1, p, u, o)
    | .proven => (d, p + 1, u, o)
    | .unproven => (d, p, u + 1, o)
    | .outside => (d, p, u, o + 1)

/-- Corpus checks over the accepted lines. Returns violation strings —
each fails a conformance batch and is one more reason a forged batch
can't pass. -/
def corpusViolations
    (claimLines : List String) (parsed : List ClaimLine)
    (censuses : List (Nat × Nat × Nat × Nat × Nat))
    (censusPositions : List Nat) (lastIdx : Nat) : List String := Id.run do
  let mut out : List String := []
  -- exactly one census, and it is the last vocabulary line
  if censuses.isEmpty then out := out ++ ["missing [claim-census]"]
  if censuses.length > 1 then out := out ++ [s!"{censuses.length} [claim-census] lines — exactly one committed"]
  for pos in censusPositions do
    if pos != lastIdx then out := out ++ ["[claim-census] is not the last vocabulary line"]
  -- census honesty
  for (cn, dn, pn, un, on) in censuses do
    let (d, p, u, o) := countVerdicts (parsed.map (·.verdict))
    if cn != parsed.length then
      out := out ++ [s!"census claims={cn} but {parsed.length} [claim-check] lines emitted"]
    if dn != d then out := out ++ [s!"census declared={dn} but {d} emitted"]
    if pn != p then out := out ++ [s!"census proven={pn} but {p} emitted"]
    if un != u then out := out ++ [s!"census unproven={un} but {u} emitted"]
    if on != o then out := out ++ [s!"census outside={on} but {o} emitted"]
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
-- census: the five fields in fixed order, each a nat
example : ruleCensus ("[claim-census] claims=3 declared=1 proven=1 unproven=1 outside=0".splitOn " ") = some (3, 1, 1, 1, 0) := by native_decide
example : ruleCensus ("[claim-census] claims=3 proven=1 declared=1 unproven=1 outside=0".splitOn " ") = none := by native_decide
example : ruleCensus ("[claim-census] claims=3 declared=1 proven=1 unproven=1".splitOn " ") = none := by native_decide
example : ruleCensus ("[claim-census] claims=x declared=1 proven=1 unproven=1 outside=0".splitOn " ") = none := by native_decide
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
  let mut censuses : List (Nat × Nat × Nat × Nat × Nat) := []
  let mut censusPositions : List Nat := []
  let mut idx : Nat := 0
  for line in lines do
    let toks := line.splitOn " "
    let isCensus := line.startsWith "[claim-census]"
    let mut ruling : Ruling := .malformed
    if isCensus then
      match ruleCensus toks with
      | some c =>
        censuses := c :: censuses
        censusPositions := idx :: censusPositions
        ruling := .match_
      | none => ruling := .malformed
    else
      match ruleClaim toks with
      | .match_ =>
        if let some (file, ln) := parseSite toks[2]! then
          if let some v := readVerdict toks[6]! then
            parsed := ⟨file, ln, toks[3]!, toks[5]!, v,
              String.intercalate " " (toks.drop 8)⟩ :: parsed
        claimLines := line :: claimLines
        ruling := .match_
      | .malformed => ruling := .malformed
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
  for v in corpusViolations claimLines.reverse parsed.reverse censuses censusPositions lastIdx do
    if !forged then bad := bad + 1
    IO.println s!"{if forged then "ok  " else "BAD "} LEDGER-VIOLATION  {v}"
  let mode := if forged then "forged (all must reject)" else "conformance (all must match)"
  IO.println s!"{mode}: {lines.length} lines, {bad} bad"
  return (if bad == 0 then 0 else 1)

end Koru.ClaimsCheck

def main (args : List String) : IO UInt32 := Koru.ClaimsCheck.main args
