/-
K3 — stored-write-numeric witness fragment.

Role A (calculus + soundness) and Role B (conformance oracle) for the
`@witness("stored-write-numeric", …)` marks the `stored` transform mints
onto lowered write invocations (koru_std/store.cols.kz, storedWriteCheck).
The pass is the untrusted solver; this file re-decides every witness from
its own definitions and rules on agreement (N1: solver ≠ checker).

Independence: the float literal rule here is a direct search for an exact
`m·2^e` witness over the format's whole exponent range — a different
derivation from the solver's odd-part/bit-length formula, so drift in
either one surfaces as a mismatch rather than agreeing by construction.

Run (Role B):  lean --run StoredWriteNumeric.lean <corpus>            — every site line must MATCH
               lean --run StoredWriteNumeric.lean --forged <corpus>   — every line must be REJECTED (N4)
A corpus is backend output; only `[witness] site …` lines are read. A
corpus with zero site lines FAILs: an empty batch is not a passed batch.
-/

namespace Koru.K3.StoredWriteNumeric

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
  dest    : String
  src     : String
  verdict : String

/-- `[witness] site <kind> <site> <dest><-<src> <verdict>` -/
def parseSiteLine (line : String) : Option SiteLine :=
  match (line.splitOn " ").filter (· ≠ "") with
  | ["[witness]", "site", kind, site, ds, verdict] =>
    (splitOnArrow ds.toList).map fun (d, s) =>
      ⟨kind, site, String.ofList d, String.ofList s, verdict⟩
  | _ => none

inductive Ruling where
  | match_ | mismatch (want : String) | malformed
deriving Repr

def rule (s : SiteLine) : Ruling :=
  if s.kind ≠ "stored-write-numeric" then .malformed
  else match decideWitness s.dest s.src, Verdict.ofTag s.verdict with
    | some v, some claimed => if v == claimed then .match_ else .mismatch v.tag
    | _, _ => .malformed

def isSiteLine (line : String) : Bool :=
  line.startsWith "[witness] site "

def parseArgs : List String → Option (Bool × String)
  | ["--forged", p] => some (true, p)
  | [p] => some (false, p)
  | _ => none

def main (args : List String) : IO UInt32 := do
  let some (forged, path) := parseArgs args
    | do IO.eprintln "usage: StoredWriteNumeric [--forged] <corpus>"; return 2
  let lines := (← IO.FS.lines path).toList.filter isSiteLine
  if lines.isEmpty then
    IO.println s!"FAIL: no [witness] site lines in {path}"
    return 1
  let mut bad := 0
  for line in lines do
    let ruling := match parseSiteLine line with
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
  let mode := if forged then "forged (all must reject)" else "conformance (all must match)"
  IO.println s!"{mode}: {lines.length} lines, {bad} bad"
  return (if bad == 0 then 0 else 1)

end Koru.K3.StoredWriteNumeric

def main (args : List String) : IO UInt32 := Koru.K3.StoredWriteNumeric.main args
