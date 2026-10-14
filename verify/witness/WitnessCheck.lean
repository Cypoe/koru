/-
Witness checker.

Role A (calculus + soundness) and Role B (conformance oracle) for the
witness kinds pass-witness-check consumes — `stored-write-numeric` (marks
the `stored` transform mints onto lowered write invocations,
koru_std/store.cols.kz, storedWriteCheck), `auto-discharge` (marks the
inserter mints onto lowered disposals, src/auto_discharge_inserter.zig),
and `custody-edge` (obligation lifecycle edges the .full phantom checker
emits, src/phantom_semantic_checker.zig).
The passes are the untrusted solvers; this file re-decides every witness
from its own definitions and rules on agreement (N1: solver ≠ checker).

Independence: the float literal rule here is a direct search for an exact
`m·2^e` witness over the format's whole exponent range — a different
derivation from the solver's odd-part/bit-length formula, so drift in
either one surfaces as a mismatch rather than agreeing by construction.

Run (Role B):  lean --run WitnessCheck.lean <corpus>            — every site line must MATCH
               lean --run WitnessCheck.lean --forged <corpus>   — every line must be REJECTED (N4)
A corpus is backend output; only `[witness] site …` lines are read. A
corpus with zero site lines FAILs: an empty batch is not a passed batch.
-/

namespace Koru.WitnessCheck

/-! ## The type table — mirrors `writeNumInfoOf` -/

inductive NumTy where
  | i32 | i64 | f32 | f64
deriving DecidableEq, Repr

inductive Cls where
  | si | fl
deriving DecidableEq, Repr

def NumTy.cls : NumTy → Cls
  | .i32 => .si | .i64 => .si | .f32 => .fl | .f64 => .fl

def NumTy.rank : NumTy → Nat
  | .i32 => 1 | .i64 => 2 | .f32 => 1 | .f64 => 2

def NumTy.ofName : String → Option NumTy
  | "i32" => some .i32 | "i64" => some .i64
  | "f32" => some .f32 | "f64" => some .f64
  | _ => none

/-! ## Value semantics

Integers of width `w`: `-2^(w-1) ≤ v ≤ 2^(w-1) - 1`, as a sign + magnitude.
Floats: the finite values are exactly `±m·2^e` with `m < 2^p` and
`emin ≤ e ≤ emax` — subnormals and normals in one set. -/

structure FFmt where
  p    : Nat
  emin : Int
  emax : Int

def NumTy.width : NumTy → Nat
  | .i32 => 32 | .i64 => 64 | _ => 0

def NumTy.fmt : NumTy → FFmt
  | .f32 => ⟨24, -149, 104⟩
  | .f64 => ⟨53, -1074, 971⟩
  | _    => ⟨0, 0, 0⟩

/-- Sign-magnitude integer `(neg, q)` is a value of the `w`-bit signed type. -/
def InInt (w : Nat) (neg : Bool) (q : Nat) : Prop :=
  if neg then q ≤ 2 ^ (w - 1) else q + 1 ≤ 2 ^ (w - 1)

/-- `(m, e)` is a representation of a finite value of format `f`. -/
def InFloat (f : FFmt) (m : Nat) (e : Int) : Prop :=
  m < 2 ^ f.p ∧ f.emin ≤ e ∧ e ≤ f.emax

/-! ## Verdicts -/

inductive Verdict where
  | lossless | deferred | rounds | nonNumeric | refused
deriving DecidableEq, Repr

def Verdict.ofTag : String → Option Verdict
  | "lossless" => some .lossless | "deferred" => some .deferred
  | "rounds" => some .rounds | "non-numeric" => some .nonNumeric
  | "refused" => some .refused
  | _ => none

def Verdict.tag : Verdict → String
  | .lossless => "lossless" | .deferred => "deferred" | .rounds => "rounds"
  | .nonNumeric => "non-numeric" | .refused => "refused"

/-! ## Typed writes: a proven source type into a column type -/

def decideTyped (dest src : NumTy) : Verdict :=
  if src.cls ≠ dest.cls ∨ src.rank > dest.rank then .refused else .lossless

/-! ## Literal writes

A decimal literal `±n / 10^k` (digits[.digits], optional leading `-`). -/

structure Lit where
  neg : Bool
  n   : Nat
  k   : Nat

def digitsVal (cs : List Char) : Nat :=
  cs.foldl (fun a c => a * 10 + (c.toNat - '0'.toNat)) 0

def parseLit (cs : List Char) : Option Lit :=
  let (neg, body) := match cs with
    | '-' :: rest => (true, rest)
    | _ => (false, cs)
  let (ip, rest) := body.span (· != '.')
  if ip.isEmpty || !ip.all Char.isDigit then none
  else match rest with
    | [] => some ⟨neg, digitsVal ip, 0⟩
    | _ :: fp =>
      if fp.isEmpty || !fp.all Char.isDigit then none
      else some ⟨neg, digitsVal (ip ++ fp), fp.length⟩

def intExact (w : Nat) (l : Lit) : Bool :=
  l.n % 10 ^ l.k == 0 &&
    (if l.neg then decide (l.n / 10 ^ l.k ≤ 2 ^ (w - 1))
     else decide (l.n / 10 ^ l.k + 1 ≤ 2 ^ (w - 1)))

/-- Does `n / 10^k = m · 2^e` hold for some integer `m < 2^p`, at this `e`? -/
def witnessAt (f : FFmt) (l : Lit) (e : Int) : Bool :=
  if e ≤ 0 then
    -- n · 2^(-e) = m · 10^k
    l.n * 2 ^ e.natAbs % 10 ^ l.k == 0 && decide (l.n * 2 ^ e.natAbs / 10 ^ l.k < 2 ^ f.p)
  else
    -- n = m · 10^k · 2^e
    l.n % (10 ^ l.k * 2 ^ e.natAbs) == 0 && decide (l.n / (10 ^ l.k * 2 ^ e.natAbs) < 2 ^ f.p)

def floatExact (f : FFmt) (l : Lit) : Bool :=
  (List.range ((f.emax - f.emin).toNat + 1)).any fun i => witnessAt f l (f.emin + i)

def litExact (dest : NumTy) (l : Lit) : Bool :=
  match dest.cls with
  | .si => intExact dest.width l
  | .fl => floatExact dest.fmt l

/-! ## The checker: one witness triple → the verdict it must carry

`none` = malformed witness (an unknown source token, an unparseable
literal) — never a verdict. -/

def prefixLiteral : List Char := "literal:".toList

def decideWitness (dest src : String) : Option Verdict :=
  match NumTy.ofName dest with
  | none => if dest == "unresolved" then some .nonNumeric else none
  | some td =>
    if src == "unproven" then some .deferred
    else if src.toList.take prefixLiteral.length == prefixLiteral then
      (parseLit (src.toList.drop prefixLiteral.length)).map fun l =>
        if litExact td l then .lossless else .rounds
    else (NumTy.ofName src).map (decideTyped td)

/-! ## Role A — soundness

A `lossless` verdict is a promise that every value the source can hold
lands in the column unchanged. These theorems discharge that promise
against the value semantics above. -/

/-- Typed widening: the source's value set embeds in the column's. -/
theorem typed_lossless_sound (dest src : NumTy) (h : decideTyped dest src = .lossless) :
    (src.cls = .si → ∀ neg q, InInt src.width neg q → InInt dest.width neg q) ∧
    (src.cls = .fl → ∀ m e, InFloat src.fmt m e → InFloat dest.fmt m e) := by
  cases dest <;> cases src <;> simp [decideTyped, NumTy.cls, NumTy.rank] at h <;>
    refine ⟨fun hc => ?_, fun hc => ?_⟩ <;> simp [NumTy.cls] at hc <;>
    first
    | (intro neg q hq; cases neg <;> simp [InInt, NumTy.width] at hq ⊢ <;> omega)
    | (intro m e hmf; simp [InFloat, NumTy.fmt] at hmf ⊢; omega)

/-- A `lossless` literal into an integer column is an in-range integer. -/
theorem int_literal_sound (w : Nat) (l : Lit) (h : intExact w l = true) :
    l.n % 10 ^ l.k = 0 ∧ InInt w l.neg (l.n / 10 ^ l.k) := by
  simp only [intExact, Bool.and_eq_true, beq_iff_eq] at h
  refine ⟨h.1, ?_⟩
  unfold InInt
  cases hn : l.neg <;> simp_all

/-- A `lossless` literal into a float column has an exact representation
`(m, e)` in the format: the decimal equals `m · 2^e` exactly. The format
must have a non-empty exponent range — both real formats do. -/
theorem float_literal_sound (f : FFmt) (l : Lit) (hf : f.emin ≤ f.emax) (h : floatExact f l = true) :
    ∃ m e, InFloat f m e ∧
      (e ≤ 0 → l.n * 2 ^ e.natAbs = m * 10 ^ l.k) ∧
      (0 < e → l.n = m * (10 ^ l.k * 2 ^ e.natAbs)) := by
  simp only [floatExact, List.any_eq_true, List.mem_range] at h
  obtain ⟨i, hi, hw⟩ := h
  have hlo : f.emin ≤ f.emin + (i : Int) := by omega
  have hhi : f.emin + (i : Int) ≤ f.emax := by omega
  unfold witnessAt at hw
  split at hw
  · rename_i he
    simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at hw
    refine ⟨l.n * 2 ^ (f.emin + i).natAbs / 10 ^ l.k, f.emin + i, ⟨hw.2, hlo, hhi⟩, ?_, ?_⟩
    · intro _
      exact (Nat.div_mul_cancel (Nat.dvd_of_mod_eq_zero hw.1)).symm
    · intro h0; omega
  · rename_i he
    simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at hw
    refine ⟨l.n / (10 ^ l.k * 2 ^ (f.emin + i).natAbs), f.emin + i, ⟨hw.2, hlo, hhi⟩, ?_, ?_⟩
    · intro h0; omega
    · intro _
      exact (Nat.div_mul_cancel (Nat.dvd_of_mod_eq_zero hw.1)).symm

/-! ## Role B — the batch oracle -/

def splitOnArrow : List Char → Option (List Char × List Char)
  | '<' :: '-' :: rest => some ([], rest)
  | c :: rest => (splitOnArrow rest).map fun (a, b) => (c :: a, b)
  | [] => none

structure SiteLine where
  kind    : String
  site    : String
  arrow   : String
  verdict : String
  extra   : String      -- optional fifth payload token ("" when absent)

/-- `[witness] site <kind> <site> <arrow> <verdict> [extra]` — the arrow and
verdict are interpreted per kind; `extra` is per-kind optional payload
(auto-discharge carries `all:` — the enumeration commitment). -/
def parseSiteLine (line : String) : Option SiteLine :=
  match (line.splitOn " ").filter (· ≠ "") with
  | ["[witness]", "site", kind, site, arrow, verdict] => some ⟨kind, site, arrow, verdict, ""⟩
  | ["[witness]", "site", kind, site, arrow, verdict, extra] => some ⟨kind, site, arrow, verdict, extra⟩
  | _ => none

inductive Ruling where
  | match_ | mismatch (want : String) | malformed
deriving Repr

/-! ## Kind `auto-discharge` — the unattended-discharge policy

The inserter (src/auto_discharge_inserter.zig, `pickUnattendedDischarge`)
splices a disposer at a scope exit only when the choice is forced: exactly
one candidate (`sole`), or several of which exactly one carries `[!]`
(`preferred`). The mark records the obligation's state, the chosen
disposer, the rule, and the full candidate list with `[!]` flags:

    <state>-><chosen>   <rule>:<cand>[!],<cand>[!],...

The checker re-runs the policy over the recorded candidates. The optional
fifth token is the completeness commitment — `all:` followed by EVERY decl
the solver enumerated for this (state, base) pair, `(x)`-suffixed on the
enumerated-but-ineligible (output-carrying, re-issuing, unfillable input):

    <state>-><chosen>   <rule>:<cand>[!],...   all:<name>[!][(x)],...

The checkable contract: the recorded candidate list must BE exactly the
non-`(x)` members of the enumeration — the solver commits to its universe,
so a candidate outside `all` or an eligible `all` member dropped from the
candidates is internally inconsistent data, not a judgment call. What
remains solver-reported is the enumeration itself: an event the solver
never saw is invisible to this fragment — that completeness needs the
declaration corpus, not the mark. -/

structure Cand where
  name : String
  dflt : Bool
deriving DecidableEq, Repr

def parseCand (s : String) : Option Cand :=
  if s.isEmpty then none
  else if s.endsWith "!" then
    let n := String.ofList (s.toList.dropLast)
    if n.isEmpty then none else some ⟨n, true⟩
  else some ⟨s, false⟩

def parseCands (s : String) : Option (List Cand) :=
  (s.splitOn ",").mapM parseCand

/-- The policy. `none` = not unattended-dischargeable: nothing may be inserted. -/
def pick (cs : List Cand) : Option (String × String) :=
  match cs with
  | [c] => some ("sole", c.name)
  | _ => match cs.filter (·.dflt) with
    | [c] => some ("preferred", c.name)
    | _ => none

/-- Role A for the policy: whatever `pick` returns was a candidate, and the
choice was forced — the only candidate, or the only `[!]` one. -/
theorem pick_sound (cs : List Cand) (r n : String) (h : pick cs = some (r, n)) :
    ∃ c ∈ cs, c.name = n ∧
      ((r = "sole" ∧ cs = [c]) ∨ (r = "preferred" ∧ c.dflt = true ∧ cs.filter (·.dflt) = [c])) := by
  unfold pick at h
  split at h
  · rename_i c
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    exact ⟨c, by simp, h.2, Or.inl ⟨h.1.symm, rfl⟩⟩
  · split at h
    · rename_i c hf
      simp only [Option.some.injEq, Prod.mk.injEq] at h
      have hmem : c ∈ cs.filter (·.dflt) := by rw [hf]; simp
      have hc := List.mem_filter.mp hmem
      exact ⟨c, hc.1, h.2, Or.inr ⟨h.1.symm, by simpa using hc.2, hf⟩⟩
    · exact absurd h (by simp)

def splitOnRight : List Char → Option (List Char × List Char)
  | '-' :: '>' :: rest => some ([], rest)
  | c :: rest => (splitOnRight rest).map fun (a, b) => (c :: a, b)
  | [] => none

/-- A member of the `all:` enumeration — `(x)` suffix marks a consumer the
solver enumerated but could not auto-insert (output-carrying, re-issuing,
or unfillable inputs). Returns (cand, excluded). -/
def parseAllEntry (s : String) : Option (Cand × Bool) :=
  let excluded := s.endsWith "(x)"
  let base := if excluded then String.ofList (s.toList.take (s.toList.length - 3)) else s
  (parseCand base).map (·, excluded)

def ruleDischarge (s : SiteLine) : Ruling :=
  if !s.extra.startsWith "all:" then .malformed else
  match splitOnRight s.arrow.toList, s.verdict.splitOn ":" with
  | some (st, chosen), claimed :: rest =>
    if st.isEmpty then .malformed else
    match (String.ofList (s.extra.toList.drop 4)).splitOn "," |>.mapM parseAllEntry,
          parseCands (":".intercalate rest) with
    | some entries, some cs =>
      let names := entries.map (·.1.name)
      if names.length != names.eraseDups.length then .malformed else
      let eligible := entries.filterMap fun (c, ex) => if ex then none else some c
      -- completeness: the candidate list is exactly the eligible slice —
      -- names AND `!` flags must agree (Cand equality carries `dflt`)
      if !(cs.length == eligible.length && cs.all fun c => eligible.contains c) then .malformed else
      match pick cs with
      | none => .mismatch "not-dischargeable"
      | some (r, n) =>
        if r == claimed && n == String.ofList chosen then .match_
        else .mismatch s!"{r}->{n}"
    | _, _ => .malformed
  | _, _ => .malformed

def ruleNumeric (s : SiteLine) : Ruling :=
  match splitOnArrow s.arrow.toList with
  | none => .malformed
  | some (d, src) =>
    match decideWitness (String.ofList d) (String.ofList src), Verdict.ofTag s.verdict with
    | some v, some claimed => if v == claimed then .match_ else .mismatch v.tag
    | _, _ => .malformed

/-! ## Kind `custody-edge` — obligation mint/settle edges

The phantom semantic checker (src/phantom_semantic_checker.zig) walks the
post-insertion flow and prints one edge per custody event it observes:

    [witness] site custody-edge <name> <name><-<T<state!>> <op>

`<name>` is the binding; the arrow repeats it and carries the obligation's
proto (`base_type<phantom_state>`). The ops:

  - `mint`      — a `state!` binding entered the cleanup audit
                  (BindingContext.setWithType, requires_cleanup).
  - `held`      — an obligation arrived through a declared consume input
                  (`<!state>`): the debt is real but settled by the event's
                  contract, so it never enters the leak audit.
  - `discharge` — a consume call or field-suffix settled the obligation
                  (BindingContext.markDisposed).
  - `issued`    — the obligation exited live through a declared `[!]`
                  output; custody transferred to the caller.

Per line the checker can only re-decide well-formedness: the site name must
be the arrow's name, the proto must carry a `!`-state, and the op must be in
vocabulary. The real verdict is corpus-level — `custodyBalance` replays the
edge list per arrow and requires

    mint      ⇒ exactly one settle (discharge or issued) before re-bind/end
    held      ⇒ at most one discharge (settlement may be contract-invisible)
    discharge/issued ⇒ an outstanding mint or held must precede them

— the witness-level twin of the checker's own leak walls. -/

def protoHasBang (proto : String) : Bool :=
  -- the proto's trailing `<state>` group must end in `!`: `...<...!>`
  proto.endsWith "!>" || proto.endsWith "!"

def ruleCustody (s : SiteLine) : Ruling :=
  match splitOnArrow s.arrow.toList with
  | none => .malformed
  | some (nm, proto) =>
    let name := String.ofList nm
    if name.isEmpty || s.site != name then .malformed
    else if !protoHasBang (String.ofList proto) then .malformed
    else match s.verdict with
      | "mint" | "held" | "discharge" | "issued" => .match_
      | _ => .malformed

/-- Ledger state for one arrow's edge sequence. -/
inductive CustodySt where
  | clean    -- no outstanding obligation
  | minted   -- a mint awaits its settle
  | heldSt   -- a held obligation may discharge or end contract-settled
deriving DecidableEq, Repr

/-- One transition; `none` = the edge is illegal here. -/
def custodyStep : CustodySt → String → Option CustodySt
  | .clean,   "mint"      => some .minted
  | .clean,   "held"      => some .heldSt
  | .minted,  "discharge" => some .clean
  | .minted,  "issued"    => some .clean
  | .heldSt,  "discharge" => some .clean
  | _,        _           => none

/-- An arrow's ledger closes iff every mint settled. A live `held` may end
open — a host impl's contract settles it invisibly. -/
def custodyClosed : CustodySt → Bool
  | .clean | .heldSt => true
  | .minted => false

/-- Replay one arrow's ops; `none` = an illegal edge occurred. -/
def custodyRun : List String → CustodySt → Option CustodySt
  | [], st => some st
  | op :: rest, st => match custodyStep st op with
    | some st' => custodyRun rest st'
    | none => none

/-- Corpus-level balance: group custody-edge lines by arrow, replay each
group's ops in file order, every ledger must close. Returns the failing
arrows (empty list = balanced). Lines that failed per-line parse are
skipped — the per-line pass already flags them. -/
def custodyBalance (sites : List SiteLine) : List String :=
  let edges := sites.filter (·.kind == "custody-edge")
  let arrows := (edges.map (·.arrow)).eraseDups
  arrows.filter fun a =>
    let ops := (edges.filter (·.arrow == a)).map (·.verdict)
    match custodyRun ops CustodySt.clean with
    | some st => !custodyClosed st
    | none => true

/-! ## Kind `descriptor` — registry descriptor ↔ event-decl fidelity

The `register|zig` transform (koru_std/runtime.kz) builds each emitted
`scope_events` row from an `EventDecl` and prints, per event,

    [witness] site descriptor <scope> <mod>:<event> <verdict> cost=<n>;decl=<atoms>;emit=<atoms>

`decl` is the declared contract serialized straight off the `EventDecl`;
`emit` is the row the transform actually generated. The obligation atoms:

  - `dis:<mod>:<state>@<arg>`           — a declared consume input `<!state>`
  - `cr:<mod>:<state>@<field>#<branch>` — a declared `<state!>` branch payload
  - `cr:<mod>:<state>@__type_ref`       — a declared `<state!>` bare return

plus shape atoms (`in:`/`br:`) mirrored verbatim on both sides. The
checker re-derives the claim set from the `decl` spellings — the same
token rule `parsePhantom` uses: a leading `!` marks a discharge, a
trailing `!` a create, and `mod:name` splits the obligation's module
from its name (falling back to the event's module) — then rules on
agreement with the `emit` claims. `discharge-refused` licenses an empty
emitted `dis` only when the declared side really carried discharges: a
declaration-only event's unsatisfiable promise is named, not silently
dropped. A `descriptor-scope` census line closes the set corpus-wide:
one per scope, `count=` equal to its descriptor lines — a resolved row
that produced no line unbalances the count. -/

/-- The first `<…>` group of a type spelling — the raw phantom token. -/
def phantomToken (t : String) : Option String :=
  match t.splitOn "<" with
  | _ :: tok :: _ =>
    match tok.splitOn ">" with
    | nm :: _ :: _ => if nm.isEmpty then none else some nm
    | _ => none
  | _ => none

/-- Mirror of `parsePhantom` (koru_std/runtime.registry.kz): leading `!`
discharges, trailing `!` creates, `mod:name` overrides the event module.
Both marks may co-occur. Returns (discharge claim, create claim) as
`mod:name` bodies. -/
def claimOf (evMod tok : String) : Option String × Option String :=
  let (dis, s1) := if tok.startsWith "!" then (true, (tok.drop 1).toString) else (false, tok)
  let (cr, s2) := if s1.endsWith "!" then (true, String.ofList s1.toList.dropLast) else (false, s1)
  if s2.isEmpty || (!dis && !cr) then (none, none)
  else
    let (m, n) := match s2.splitOn ":" with
      | a :: b :: rest => (a, ":".intercalate (b :: rest))
      | _ => (evMod, s2)
    (if dis then some s!"{m}:{n}" else none, if cr then some s!"{m}:{n}" else none)

structure DescSide where
  ins : List String   -- `in:` atoms, verbatim
  brs : List String   -- `br:` atoms, verbatim
  crs : List String   -- `cr:` claim atoms
  dis : List String   -- `dis:` claim atoms

/-- Re-derive the obligation claims a `decl` atom list carries — the
independent reading the emitted row must agree with. `none` on any atom
outside the declared vocabulary. -/
def declSide (evMod : String) : List String → DescSide → Option DescSide
  | [], acc => some acc
  | a :: rest, acc =>
    if a.startsWith "brf:" then
      match (a.drop 4).toString.splitOn "=" with
      | [lhs, ty] =>
        match lhs.splitOn ":" with
        | [br, f] =>
          let (d, c) := match phantomToken ty with
            | some tok => claimOf evMod tok
            | none => (none, none)
          let acc := match c with
            | some cl => { acc with crs := acc.crs ++ [s!"cr:{cl}@{f}#{br}"] }
            | none => acc
          let acc := match d with
            | some cl => { acc with dis := acc.dis ++ [s!"dis:{cl}@{f}#{br}"] }
            | none => acc
          declSide evMod rest acc
        | _ => none
      | _ => none
    else if a.startsWith "in:" then
      match (a.drop 3).toString.splitOn "=" with
      | [n, ty] =>
        let acc := { acc with ins := acc.ins ++ [a] }
        match phantomToken ty with
        | none => declSide evMod rest acc
        | some tok =>
          let (d, c) := claimOf evMod tok
          let acc := match d with
            | some cl => { acc with dis := acc.dis ++ [s!"dis:{cl}@{n}"] }
            | none => acc
          let acc := match c with
            | some cl => { acc with crs := acc.crs ++ [s!"cr:{cl}@{n}"] }
            | none => acc
          declSide evMod rest acc
      | _ => none
    else if a.startsWith "br:" then
      declSide evMod rest { acc with brs := acc.brs ++ [a] }
    else if a.startsWith "ret:" then
      match phantomToken (a.drop 4).toString with
      | none => declSide evMod rest acc
      | some tok =>
        let (d, c) := claimOf evMod tok
        let acc := match c with
          | some cl => { acc with crs := acc.crs ++ [s!"cr:{cl}@__type_ref"] }
          | none => acc
        let acc := match d with
          | some cl => { acc with dis := acc.dis ++ [s!"dis:{cl}@__type_ref"] }
          | none => acc
        declSide evMod rest acc
    else none

/-- Partition an `emit` atom list; `none` on any atom outside the emitted
vocabulary — a claim shape the checker cannot read is flagged, not
skipped. -/
def emitSide : List String → DescSide → Option DescSide
  | [], acc => some acc
  | a :: rest, acc =>
    if a.startsWith "cr:" then emitSide rest { acc with crs := acc.crs ++ [a] }
    else if a.startsWith "dis:" then emitSide rest { acc with dis := acc.dis ++ [a] }
    else if a.startsWith "in:" then emitSide rest { acc with ins := acc.ins ++ [a] }
    else if a.startsWith "br:" then emitSide rest { acc with brs := acc.brs ++ [a] }
    else none

def parseDescExtra (extra : String) : Option (List String × List String) :=
  match extra.splitOn ";" with
  | [cTok, dTok, eTok] =>
    if !cTok.startsWith "cost=" || !dTok.startsWith "decl=" || !eTok.startsWith "emit=" then none
    else match (cTok.drop 5).toString.toNat? with
      | none => none
      | some _ =>
        some ((dTok.drop 5).toString.splitOn "|" |>.filter (· ≠ ""),
              (eTok.drop 5).toString.splitOn "|" |>.filter (· ≠ ""))
  | _ => none

def setEq (a b : List String) : Bool := a.all (· ∈ b) && b.all (· ∈ a)

def ruleDescriptor (s : SiteLine) : Ruling :=
  let evMod := match s.arrow.splitOn ":" with
    | m :: _ => m
    | [] => ""
  if evMod.isEmpty then .malformed else
  match parseDescExtra s.extra with
  | none => .malformed
  | some (declAtoms, emitAtoms) =>
    match declSide evMod declAtoms ⟨[], [], [], []⟩, emitSide emitAtoms ⟨[], [], [], []⟩ with
    | some d, some e =>
      let shape := setEq d.ins e.ins && setEq d.brs e.brs && setEq d.crs e.crs
      if s.verdict == "registered" then
        if shape && setEq d.dis e.dis then .match_
        else .mismatch s!"{d.ins ++ d.brs ++ d.crs ++ d.dis} vs {e.ins ++ e.brs ++ e.crs ++ e.dis}"
      else if s.verdict == "discharge-refused" then
        if shape && e.dis.isEmpty && !d.dis.isEmpty then .match_
        else .mismatch s!"refused {d.dis} vs {e.dis}"
      else .malformed
    | _, _ => .malformed

def ruleDescriptorScope (s : SiteLine) : Ruling :=
  if s.site != s.arrow || s.verdict != "events" then .malformed
  else match s.extra.splitOn "=" with
    | ["count", n] => match n.toNat? with
      | some _ => .match_
      | none => .malformed
    | _ => .malformed

/-- Corpus-level completeness: every scope carrying descriptor lines must
carry exactly one `descriptor-scope` census whose `count=` equals the
number of its descriptor lines — a resolved row that produced no line
unbalances the count; a scope with no census line fails too. -/
def descriptorScopeBalance (sites : List SiteLine) : List String :=
  let descs := sites.filter (·.kind == "descriptor")
  let cens := sites.filter (·.kind == "descriptor-scope")
  let scopes := (descs.map (·.site) ++ cens.map (·.site)).eraseDups
  scopes.filter fun sc =>
    let n := (descs.filter (·.site == sc)).length
    match cens.filter (·.site == sc) with
    | [c] =>
      (match c.extra.splitOn "=" with
       | ["count", k] => k.toNat? != some n
       | _ => true)
    | _ => true

/-! ## Kind `transform-app` — whole-program transform accounting (K2 Use B)

`whole_program` is the one SiteResult splice where a handler may rewrite
top-level items outside its site (koru_std/taps.kz); the comptime-only-site
flow removal is the only other transform-driven top-level removal. The
runner (src/transform_pass_runner.zig `emitTransformAppLine`) commits, per
application, the site's canonical-AST digest and the multiset diff of
top-level item digests:

    <transform> <site-flow>   wp   site=<d>;rm=<d,...>;add=<d,...>
    <transform> <site-flow>   gc   site=<d>;rm=<d>;add=

The checkable contract is accounting honesty, not yet confinement bounds:
a `wp` line must list its site item among the removed digests (the splice
returned a program where the site item changed or vanished — an untouched
site under a whole-program rewrite is a lie the digest can tell), and a
`gc` line is by construction a singleton removal of the site itself.
Blast-radius declarations are pass-graph surface; nothing here bounds
which OTHER items a transform may touch. -/

def isHexDigest (d : String) : Bool :=
  d.length == 16 && d.all fun c => c ∈ "0123456789abcdef".toList

def digestList (raw : String) : Option (List String) :=
  if raw.isEmpty then some []
  else
    let parts := raw.splitOn ","
    if parts.all isHexDigest then some parts else none

def parseAppExtra (extra : String) : Option (String × List String × List String) :=
  match extra.splitOn ";" with
  | [sTok, rTok, aTok] =>
    if !sTok.startsWith "site=" || !rTok.startsWith "rm=" || !aTok.startsWith "add=" then none
    else match digestList (rTok.drop 3).toString, digestList (aTok.drop 4).toString with
      | some rm, some add => some ((sTok.drop 5).toString, rm, add)
      | _, _ => none
  | _ => none

def ruleTransformApp (s : SiteLine) : Ruling :=
  if s.verdict != "wp" && s.verdict != "gc" then .malformed
  else match parseAppExtra s.extra with
  | none => .malformed
  | some (siteD, rm, add) =>
    if !isHexDigest siteD then .malformed
    else if s.verdict == "wp" && !rm.contains siteD then
      .mismatch s!"site {siteD} absent from rm {rm}"
    else if s.verdict == "gc" && !(rm == [siteD] && add.isEmpty) then
      .mismatch s!"gc {siteD} vs rm {rm} add {add}"
    else .match_

def ruleTransformAppCensus (s : SiteLine) : Ruling :=
  if s.site != "transform" || s.arrow != "transform" then .malformed
  else match s.verdict.splitOn "=" with
    | ["count", n] => match n.toNat? with
      | some _ => .match_
      | none => .malformed
    | _ => .malformed

/-- Corpus-level completeness for transform-app: at most one census line,
and when applications were emitted its count must equal them. A dropped
or forged application line unbalances the count. -/
def transformAppBalance (sites : List SiteLine) : Bool :=
  let apps := sites.filter (·.kind == "transform-app")
  let cens := sites.filter (·.kind == "transform-app-census")
  match apps, cens with
  | [], [] => true
  | _, [c] =>
    (match c.verdict.splitOn "=" with
     | ["count", k] => k.toNat? == some apps.length
     | _ => false)
  | _, _ => false

def rule (s : SiteLine) : Ruling :=
  if s.kind == "stored-write-numeric" then ruleNumeric s
  else if s.kind == "auto-discharge" then ruleDischarge s
  else if s.kind == "custody-edge" then ruleCustody s
  else if s.kind == "descriptor" then ruleDescriptor s
  else if s.kind == "descriptor-scope" then ruleDescriptorScope s
  else if s.kind == "transform-app" then ruleTransformApp s
  else if s.kind == "transform-app-census" then ruleTransformAppCensus s
  else .malformed

def isSiteLine (line : String) : Bool :=
  line.startsWith "[witness] site "

def parseArgs : List String → Option (Bool × String)
  | ["--forged", p] => some (true, p)
  | [p] => some (false, p)
  | _ => none

def main (args : List String) : IO UInt32 := do
  let some (forged, path) := parseArgs args
    | do IO.eprintln "usage: WitnessCheck [--forged] <corpus>"; return 2
  let lines := (← IO.FS.lines path).toList.filter isSiteLine
  if lines.isEmpty then
    IO.println s!"FAIL: no [witness] site lines in {path}"
    return 1
  let mut bad := 0
  let mut sites : List SiteLine := []
  for line in lines do
    let sOpt := parseSiteLine line
    if let some s := sOpt then sites := s :: sites
    let ruling := match sOpt with
      | none => Ruling.malformed
      | some s => rule s
    let accepted := match ruling with | .match_ => true | _ => false
    let label := match ruling with
      | .match_ => "MATCH"
      | .mismatch want => s!"MISMATCH (checker: {want})"
      | .malformed => "MALFORMED"
    -- In --forged mode every line must be rejected; otherwise every line must match.
    let ok := if forged then !accepted else accepted
    if !ok then bad := bad + 1
    IO.println s!"{if ok then "ok  " else "BAD "} {label}  {line}"
  -- Corpus-level custody balance: replay each arrow's edge ledger. An
  -- unclosed mint is a leaked obligation; an illegal edge is a ledger the
  -- checker itself could not have walked — both fail the batch either way.
  for a in custodyBalance sites.reverse do
    -- A corpus violation is rejection evidence: it fails a conformance
    -- batch, and in forged mode it is one more reason the batch can't
    -- pass — counting it as `bad` there would punish rejection itself.
    if !forged then bad := bad + 1
    IO.println s!"{if forged then "ok  " else "BAD "} UNBALANCED  {a}"
  -- Corpus-level descriptor census: every scope's count must equal its
  -- descriptor lines, and every descriptor scope must carry a census.
  for sc in descriptorScopeBalance sites.reverse do
    if !forged then bad := bad + 1
    IO.println s!"{if forged then "ok  " else "BAD "} SCOPE-DRIFT  {sc}"
  -- Corpus-level transform-app census: the count must equal the emitted
  -- application lines — a dropped or invented application unbalances it.
  if !transformAppBalance sites.reverse then
    if !forged then bad := bad + 1
    IO.println s!"{if forged then "ok  " else "BAD "} APP-DRIFT  transform-app census"
  let mode := if forged then "forged (all must reject)" else "conformance (all must match)"
  IO.println s!"{mode}: {lines.length} lines, {bad} bad"
  return (if bad == 0 then 0 else 1)

end Koru.WitnessCheck

def main (args : List String) : IO UInt32 := Koru.WitnessCheck.main args
