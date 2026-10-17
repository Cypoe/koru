import FlowKernel

/-
FlowCheck — the corpus-facing consumer of the flow kernel.

This is the second rung of the audit's §6a path: FlowKernel is the
mechanized semantics; FlowCheck is the surface that consumes emitted
`[flow-eval]` claims and re-decides them against it. The whole-program
claim (Option A): graph + entry call + asserted result + asserted
thunk leaves, checked end to end. Nothing is trusted except the
native-thunk leaves, which are foreign code the kernel cannot see —
everything Koru-expressible is re-evaluated.

Run (Role B):  lean --run FlowCheck.lean <corpus>            — every claim must MATCH
               lean --run FlowCheck.lean --forged <corpus>   — every claim must be REJECTED
A corpus is emitter output (or a fixture standing in for it); only
`[flow-eval] <sexpr>` lines are read. A corpus with zero claim lines
FAILs: an empty batch is not a passed batch.

## Wire format — one claim per line, s-expression payload

    [flow-eval] ( (entry NAME (ARGV*)) (fuel N) (result R)
                  (graph DECL*) (oracle LEAF*) )

    ARGV := (name VAL)                          named, evaluated arg
    VAL  := (int I) | (float N D)               N/D rational, D ≠ 0
          | (bool true|false) | (str "S")       no escapes — quotes end atoms
          | (arr VAL*) | (cell (name VAL)*)
    R    := refuse                              expected refusal (see fuel note)
          | (void) | (bare VAL) | (tag NAME) | (tag NAME VAL)
    DECL := (def NAME thunk)                    native — oracle leaf territory
          | (def NAME (bare EXPR))
          | (def NAME (subflow ((label L))? (head NAME ARGE*) ARM*))
    ARGE := (name EXPR)
    ARM  := (arm FIELD*)
    FIELD := (tag NAME) | catchall              catchall ⇒ branch "*" + flag
           | (bind NAME) | (when EXPR)
           | (node NODE) | (conts ARM*)
    NODE := terminal | (jump NAME ARGE*) | (invoke NAME ARGE*)
          | (produce EXPR) | (ctor NAME EXPR)
    EXPR := (lit VAL) | (var NAME)
          | (bin OP EXPR EXPR)    OP ∈ add sub mul div mod eq ne lt le
                                    gt ge and or concat
          | (un OP EXPR)          OP ∈ not neg
          | (cond C T E) | (field EXPR NAME) | (index EXPR EXPR)
          | (builtin NAME EXPR*)
    LEAF := (leaf NAME (ARGV*) R)               R must not be `refuse`

Every decoder is a total `Sx → Option T`: malformed structure is a
rejection, never an approximation. Duplicated claim fields refuse.

## Honesty notes

  * Success claims are fuel-independent once decided (`run_mono`), so
    checking at the claimed fuel is sound. A `refuse` claim is
    budget-relative by construction — "did not decide within fuel N" —
    so emitters must fuel refusal claims generously; the convention is
    pinned in the corpus files, not enforced by the checker yet.
  * Oracle leaves are the declared trust boundary: `(leaf ...)` rows
    assert what a native thunk returned. The kernel re-decides all
    control flow and expression evaluation around them, never the leaf.
  * Corpus-level rule: a byte-identical claim appearing twice is a
    drift violation — duplicated lines inflate a claimed count without
    adding coverage.
-/

namespace Koru.FlowCheck

open Koru.FlowKernel

/-! ## S-expression surface: tokenize → parse -/

inductive Sx where
  | atom : String → Sx
  | list : List Sx → Sx
deriving BEq, Repr

def isSxSpace (c : Char) : Bool :=
  c == ' ' || c == '\t' || c == '\n' || c == '\r'

/-- Collect a quoted atom's body — fueled by remaining length, one char
per step. Unterminated quote refuses. -/
def tkQuote : Nat → List Char → Option (List Char × List Char)
  | 0, _ => none
  | _, [] => none
  | _ + 1, '"' :: rest => some ([], rest)
  | fuel + 1, c :: rest => (tkQuote fuel rest).map fun (w, r) => (c :: w, r)

/-- Collect a bare atom — stops (without consuming) at a delimiter. -/
def tkAtom : Nat → List Char → List Char × List Char
  | 0, cs => ([], cs)
  | _, [] => ([], [])
  | fuel + 1, c :: rest =>
      if isSxSpace c || c == '(' || c == ')' || c == '"'
      then ([], c :: rest)
      else match tkAtom fuel rest with
           | (w, r) => (c :: w, r)

/-- Tokenize: `(`, `)`, quoted atoms kept WITH quotes (no escapes —
an unterminated quote refuses), bare atoms. Fuel is the remaining
length; every step consumes at least one char. The `[]` arm must come
first — an input that consumes its budget exactly is still a success. -/
def tkGo : Nat → List Char → Option (List String)
  | _, [] => some []
  | 0, _ => none
  | fuel + 1, c :: rest =>
      if isSxSpace c then tkGo fuel rest
      else if c == '(' then (tkGo fuel rest).map ("(" :: ·)
      else if c == ')' then (tkGo fuel rest).map (")" :: ·)
      else if c == '"' then
        match tkQuote rest.length rest with
        | some (w, rest') =>
            (tkGo fuel rest').map (String.ofList ('"' :: w ++ ['"']) :: ·)
        | none => none
      else
        match tkAtom (c :: rest).length (c :: rest) with
        | (w, rest') => (tkGo fuel rest').map (String.ofList w :: ·)

def tokenize (cs : List Char) : Option (List String) := tkGo (cs.length + 1) cs

mutual
/-- One s-expression plus leftover tokens, fueled by a step budget —
every `(` and every list element costs one unit, so `2 * toks + 2` is
always sufficient. Fuel is a bound, not a semantics. -/
def parseSx : Nat → List String → Option (Sx × List String)
  | 0, _ => none
  | _, ")" :: _ => none
  | fuel + 1, "(" :: rest =>
      (parseList fuel rest).map fun (xs, r) => (.list xs, r)
  | _, a :: rest => some (.atom a, rest)
  | _, [] => none
def parseList : Nat → List String → Option (List Sx × List String)
  | _, ")" :: rest => some ([], rest)
  | _, [] => none
  | 0, _ => none
  | fuel + 1, toks =>
      match parseSx fuel toks with
      | some (x, rest) => (parseList fuel rest).map fun (xs, r) => (x :: xs, r)
      | none => none
end

/-- A full line must be exactly one s-expression — trailing tokens
refuse. -/
def parseTop (line : String) : Option Sx :=
  match tokenize line.toList with
  | some toks =>
      match parseSx (2 * toks.length + 2) toks with
      | some (x, []) => some x
      | _ => none
  | none => none

/-! ## Decoders — `Sx → Option T`, explicit refusal everywhere -/

def sxInt (s : String) : Option Int :=
  if s.startsWith "-"
  then (s.drop 1).toNat?.map fun n => -(Int.ofNat n)
  else s.toNat?.map Int.ofNat

def sxBinOp : String → Option BinOp
  | "add" => some .add     | "sub" => some .sub | "mul" => some .mul
  | "div" => some .div     | "mod" => some .mod
  | "eq" => some .eq       | "ne" => some .ne
  | "lt" => some .lt       | "le" => some .le
  | "gt" => some .gt       | "ge" => some .ge
  | "and" => some .and     | "or" => some .or  | "concat" => some .concat
  | _ => none

def sxUnOp : String → Option UnOp
  | "not" => some .not | "neg" => some .neg
  | _ => none

/-- Bare atom, unquoted — names. -/
def sxName : Sx → Option String
  | .atom s => if s.startsWith "\"" then none else some s
  | _ => none

/-- Quoted atom, quotes stripped — strings. -/
def sxStr (s : String) : Option String :=
  if s.startsWith "\"" && s.endsWith "\"" && s.length ≥ 2
  then some (String.ofList ((s.toList.drop 1).dropLast))
  else none

mutual
def sxVal : Sx → Option Val
  | .list [.atom "int", .atom i] => (sxInt i).map .int
  | .list [.atom "float", .atom n, .atom d] =>
      match sxInt n, sxInt d with
      | some n', some d' =>
          if d' == 0 then none else some (.float (Float.ofInt n' / Float.ofInt d'))
      | _, _ => none
  | .list [.atom "bool", .atom "true"] => some (.bool true)
  | .list [.atom "bool", .atom "false"] => some (.bool false)
  | .list [.atom "str", .atom s] => (sxStr s).map .str
  | .list (.atom "arr" :: xs) => (sxValList xs).map .arr
  | .list (.atom "cell" :: fs) => (sxNamedValList fs).map .cell
  | _ => none

def sxValList : List Sx → Option (List Val)
  | [] => some []
  | x :: rest =>
      match sxVal x, sxValList rest with
      | some v, some vs => some (v :: vs)
      | _, _ => none

def sxNamedVal : Sx → Option (String × Val)
  | .list [.atom n, v] => match sxVal v with
      | some v' => some (n, v')
      | none => none
  | _ => none

def sxNamedValList : List Sx → Option (List (String × Val))
  | [] => some []
  | x :: rest =>
      match sxNamedVal x, sxNamedValList rest with
      | some p, some ps => some (p :: ps)
      | _, _ => none

def sxExpr : Sx → Option Expr
  | .list [.atom "lit", v] => (sxVal v).map .lit
  | .list [.atom "var", .atom n] => some (.var n)
  | .list [.atom "bin", .atom op, a, b] =>
      match sxBinOp op, sxExpr a, sxExpr b with
      | some op', some a', some b' => some (.bin op' a' b')
      | _, _, _ => none
  | .list [.atom "un", .atom op, a] =>
      match sxUnOp op, sxExpr a with
      | some op', some a' => some (.un op' a')
      | _, _ => none
  | .list [.atom "cond", c, t, e] =>
      match sxExpr c, sxExpr t, sxExpr e with
      | some c', some t', some e' => some (.cond c' t' e')
      | _, _, _ => none
  | .list [.atom "field", o, .atom n] => (sxExpr o).map (.field · n)
  | .list [.atom "index", o, i] =>
      match sxExpr o, sxExpr i with
      | some o', some i' => some (.index o' i')
      | _, _ => none
  | .list (.atom "builtin" :: .atom n :: args) =>
      (sxExprList args).map (.builtin n)
  | _ => none

def sxExprList : List Sx → Option (List Expr)
  | [] => some []
  | x :: rest =>
      match sxExpr x, sxExprList rest with
      | some e, some es => some (e :: es)
      | _, _ => none

def sxNamedExpr : Sx → Option (String × Expr)
  | .list [.atom n, e] => (sxExpr e).map (n, ·)
  | _ => none

def sxNamedExprList : List Sx → Option (List (String × Expr))
  | [] => some []
  | x :: rest =>
      match sxNamedExpr x, sxNamedExprList rest with
      | some p, some ps => some (p :: ps)
      | _, _ => none

def sxArmNode : Sx → Option ArmNode
  | .atom "terminal" => some .terminal
  | .list (.atom "jump" :: .atom n :: args) =>
      (sxNamedExprList args).map (.jump n)
  | .list (.atom "invoke" :: .atom n :: args) =>
      (sxNamedExprList args).map (.invoke n)
  | .list [.atom "produce", e] => (sxExpr e).map .produce
  | .list [.atom "ctor", .atom n, e] => (sxExpr e).map (.retCtor n)
  | _ => none

/-- Arm fields fold — order-free, every field may appear at most once.
`catchall` sets branch `*` AND the flag, matching the walker's stored
shape (catchall arms carry `branch = "*"` and tagged dispatch compares
names only). -/
def sxArmFields : List Sx → Arm → Option Arm
  | [], a => some a
  | .list [.atom "tag", .atom n] :: rest, a =>
      if a.branch != "" then none
      else sxArmFields rest { a with branch := n }
  | .atom "catchall" :: rest, a =>
      if a.catchall || a.branch != "" then none
      else sxArmFields rest { a with branch := "*", catchall := true }
  | .list [.atom "bind", .atom n] :: rest, a =>
      if a.bind.isSome then none
      else sxArmFields rest { a with bind := some n }
  | .list [.atom "when", e] :: rest, a =>
      if a.cond.isSome then none
      else match sxExpr e with
           | some e' => sxArmFields rest { a with cond := some e' }
           | none => none
  | .list [.atom "node", n] :: rest, a =>
      if a.node.isSome then none
      else match sxArmNode n with
           | some n' => sxArmFields rest { a with node := some n' }
           | none => none
  | .list (.atom "conts" :: cs) :: rest, a =>
      if !a.conts.isEmpty then none
      else match sxArmList cs with
           | some cs' => sxArmFields rest { a with conts := cs' }
           | none => none
  | _ :: _, _ => none

def sxArm : Sx → Option Arm
  | .list (.atom "arm" :: fields) => sxArmFields fields {}
  | _ => none

def sxArmList : List Sx → Option (List Arm)
  | [] => some []
  | x :: rest =>
      match sxArm x, sxArmList rest with
      | some a, some as => some (a :: as)
      | _, _ => none

/-- `(label L)? (head NAME ARGE*) ARM*` — the subflow body after the
`subflow` tag. -/
def sxFlowBody : List Sx → Option Flow
  | .list [.atom "label", .atom l] :: .list (.atom "head" :: .atom h :: args) :: arms =>
      match sxNamedExprList args, sxArmList arms with
      | some args', some arms' =>
          some { preLabel := some l, head := (h, args'), arms := arms' }
      | _, _ => none
  | .list (.atom "head" :: .atom h :: args) :: arms =>
      match sxNamedExprList args, sxArmList arms with
      | some args', some arms' =>
          some { head := (h, args'), arms := arms' }
      | _, _ => none
  | _ => none

def sxDecl : Sx → Option (String × Callable)
  | .list [.atom "def", .atom n, .atom "thunk"] => some (n, .thunk)
  | .list [.atom "def", .atom n, .list (.atom "bare" :: [e])] =>
      (sxExpr e).map fun e' => (n, .bare e')
  | .list [.atom "def", .atom n, .list (.atom "subflow" :: body)] =>
      (sxFlowBody body).map fun f => (n, .subflow f)
  | _ => none

def sxDeclList : List Sx → Option (List (String × Callable))
  | [] => some []
  | x :: rest =>
      match sxDecl x, sxDeclList rest with
      | some d, some ds => some (d :: ds)
      | _, _ => none

/-- A thunk-result form (void/bare/tag) — `refuse` is NOT a leaf value;
a thunk that fails is a refusal at its call site, not an assertable
leaf. -/
def sxThunkResult : Sx → Option Result
  | .list [.atom "void"] => some {}
  | .list [.atom "bare", v] => (sxVal v).map fun v' => { payload := some v' }
  | .list [.atom "tag", .atom n] => some { branch := some n }
  | .list [.atom "tag", .atom n, v] =>
      (sxVal v).map fun v' => { branch := some n, payload := some v' }
  | _ => none

def sxLeaf : Sx → Option ((String × List (String × Val)) × Result)
  | .list [.atom "leaf", .atom n, .list args, r] =>
      match sxNamedValList args, sxThunkResult r with
      | some args', some r' => some ((n, args'), r')
      | _, _ => none
  | _ => none

def sxLeafList : List Sx → Option (List ((String × List (String × Val)) × Result))
  | [] => some []
  | x :: rest =>
      match sxLeaf x, sxLeafList rest with
      | some l, some ls => some (l :: ls)
      | _, _ => none

/-- The claim's expected field: `refuse` → `none` (eval must not
decide), otherwise a `Result`. -/
def sxExpected : Sx → Option (Option Result)
  | .atom "refuse" => some none
  | r => (sxThunkResult r).map some

end

/-! ## The claim and its re-decision -/

structure Claim where
  graph : Graph
  oracle : Oracle
  entry : String
  args : List (String × Val)
  fuel : Nat
  expected : Option Result
  /-- The unspliced residue arms the result dispatches into — the
  observable half of the claim (A.5): the checker re-dispatches and
  re-renders the output itself rather than trusting the emitter's
  splice. Absent = the step has no residue. -/
  residue : List Arm := []
deriving Repr

/-- Claim fields fold — tagged forms, each required exactly once
(`residue` optional, defaults to none). -/
private structure ClaimAcc where
  entry : Option (String × List (String × Val)) := none
  fuel : Option Nat := none
  expected : Option (Option Result) := none
  graph : Option Graph := none
  oracle : Option Oracle := none
  residue : Option (List Arm) := none

private def claimFields : List Sx → ClaimAcc → Option ClaimAcc
  | [], acc => some acc
  | .list (.atom "entry" :: .atom n :: args) :: rest, acc =>
      if acc.entry.isSome then none
      else match sxNamedValList args with
           | some a => claimFields rest { acc with entry := some (n, a) }
           | none => none
  | .list [.atom "fuel", .atom f] :: rest, acc =>
      if acc.fuel.isSome then none
      else match f.toNat? with
           | some n => claimFields rest { acc with fuel := some n }
           | none => none
  | .list [.atom "result", r] :: rest, acc =>
      if acc.expected.isSome then none
      else match sxExpected r with
           | some r' => claimFields rest { acc with expected := some r' }
           | none => none
  | .list (.atom "graph" :: ds) :: rest, acc =>
      if acc.graph.isSome then none
      else match sxDeclList ds with
           | some g => claimFields rest { acc with graph := some g }
           | none => none
  | .list (.atom "oracle" :: ls) :: rest, acc =>
      if acc.oracle.isSome then none
      else match sxLeafList ls with
           | some o => claimFields rest { acc with oracle := some o }
           | none => none
  | .list (.atom "residue" :: arms) :: rest, acc =>
      if acc.residue.isSome then none
      else match sxArmList arms with
           | some a => claimFields rest { acc with residue := some a }
           | none => none
  | _ :: _, _ => none

def sxClaim : Sx → Option Claim
  | .list fields =>
      match claimFields fields {} with
      | some { entry := some (n, a), fuel := some f, expected := some e,
               graph := some g, oracle := some o, residue := r } =>
          some { graph := g, oracle := o, entry := n, args := a,
                 fuel := f, expected := e, residue := r.getD [] }
      | _ => none
  | _ => none

/-- The whole check — `eval` re-decides the graph and every modeled
expression; only thunk leaves read the asserted oracle. `==` compares
the kernel's verdict against the asserted one — both directions
covered: a claimed result must be reproduced exactly, a `refuse` claim
must actually not decide. -/
def decideClaim (c : Claim) : Bool :=
  eval c.graph c.oracle c.fuel c.entry c.args == c.expected

/-- Line-level entry: strip the `[flow-eval] ` prefix, parse, decode,
re-decide. -/
def checkLine (line : String) : Option Bool :=
  (parseTop line).bind sxClaim |>.map decideClaim

/-- The wire relation a `[flow-eval]` line asserts: the line decodes to
a claim whose committed outcome the kernel's verdict is equal to —
`==`-equal, the checker's own notion, which is IEEE on floats (the
only unlawful corner: `+0.0 == -0.0` while `+0.0 ≠ -0.0`; wire floats
decode from rationals so `NaN` cannot appear, but the kernel can
produce `-0.0` — a claim that needed bit-exact `-0.0` is inexpressible,
the wire's verdict is IEEE-equal). `checkLine` is the executable half;
`WireOk` is the spec — the ISAR `step?`/`IStep` pairing: a Bool
function is a checker only once it is proved to land inside the
relation it claims to decide. -/
inductive WireOk (line : String) : Prop where
  | mk (c : Claim) :
      (parseTop line).bind sxClaim = some c →
      (eval c.graph c.oracle c.fuel c.entry c.args == c.expected) = true →
      WireOk line

/-- Soundness: `checkLine` answers MATCH only for lines in the wire
relation — it cannot pass a claim the kernel does not reproduce, and
cannot pass a line that fails to decode. `native_decide` fixtures pin
instances; this pins the whole grammar. -/
theorem checkLine_sound (line : String) :
    checkLine line = some true → WireOk line := by
  intro h
  unfold checkLine at h
  cases hp : (parseTop line).bind sxClaim with
  | none => simp [hp] at h
  | some c =>
      rw [hp] at h
      simp only [Option.map_some, Option.some.injEq] at h
      exact ⟨c, hp, h⟩

/-- Completeness: every line in the wire relation checks MATCH — the
relation and the executable check agree exactly, not only where the
checker happens to succeed. -/
theorem checkLine_complete (line : String) :
    WireOk line → checkLine line = some true := by
  rintro ⟨c, hp, he⟩
  unfold checkLine
  rw [hp]
  simp only [Option.map_some, Option.some.injEq]
  exact he

/-- REJECT is a decision, not a decode failure: `some false` answers
only on lines that parse to a claim whose outcome the kernel does not
reproduce. A malformed line can never be claimed as a refusal. -/
theorem checkLine_reject (line : String) (c : Claim) :
    checkLine line = some false →
    (parseTop line).bind sxClaim = some c →
    (eval c.graph c.oracle c.fuel c.entry c.args == c.expected) = false := by
  intro h hp
  unfold checkLine at h
  rw [hp, Option.map_some] at h
  exact Option.some.inj h

/-- The silence case: `none` iff the line never decoded to a claim —
exactly the "unparseable input says nothing" boundary. -/
theorem checkLine_none (line : String) :
    checkLine line = none ↔ (parseTop line).bind sxClaim = none := by
  unfold checkLine
  cases (parseTop line).bind sxClaim <;> simp

/-! ## A.5 — graph→C observable refinement

`checkLine` verifies the SEMANTIC half: the emitted graph re-decides
to the claimed verdict. A.5 verifies the OBSERVABLE half: the emitted
C's stdout writes equal what the KERNEL derives from
`(result, residue)` — `renderObservable` is the kernel's own
splice+render, so "refinement" never compares the emitter's output
against the emitter's own claim.

Subset — anything else is `none` (loud refusal, never a guess):
`main` is a flat sequence of `koru_flow_N();` calls ending in
`return …`; each `static void koru_flow_N(void) {…}` body is a flat
statement list of `__koru_stdout_write("…")` /
`__koru_stdout_write_i64(⟨int⟩)`; claim count must equal the call
count and they zip in order. A `;` inside a C string literal breaks
the statement split — the fragments fail to parse, which is the
intended refusal, not a silent wrong answer. -/

/-- Decode a C string-literal body — the emitter's escape set
(`\n \t \r \\ \" \'`); `\xNN`/octal/NUL refuse. -/
def cUnescape : List Char → Option String
  | [] => some ""
  | '\\' :: 'n' :: r => (cUnescape r).map ("\n" ++ ·)
  | '\\' :: 't' :: r => (cUnescape r).map ("\t" ++ ·)
  | '\\' :: 'r' :: r => (cUnescape r).map ("\r" ++ ·)
  | '\\' :: '\\' :: r => (cUnescape r).map ("\\" ++ ·)
  | '\\' :: '"' :: r => (cUnescape r).map ("\"" ++ ·)
  | '\\' :: '\'' :: r => (cUnescape r).map ("'" ++ ·)
  | '\\' :: _ => none
  | '"' :: _ => none
  | c :: r => (cUnescape r).map (String.ofList [c] ++ ·)

/-- Strip redundant parentheses — the emitter wraps printed values for
precedence (`write_i64((4))`); fuel-bounded like the rest of the
checker. -/
def stripParensF : Nat → String → String
  | 0, s => s
  | n+1, s =>
      let t := s.trimAscii.copy
      if t.startsWith "(" && t.endsWith ")" then
        stripParensF n ((t.drop 1 |>.dropEnd 1).copy)
      else t

/-- One emitted C statement's stdout contribution. -/
def cStmtText (stmt : String) : Option String :=
  let s := stmt.trimAscii.copy
  if s.isEmpty then some ""
  else if s.startsWith "__koru_stdout_write_i64" then
    let arg := (s.drop "__koru_stdout_write_i64".length).copy
    if arg.startsWith "(" && arg.endsWith ")" then
      match (stripParensF arg.length arg).toInt? with
      | some i => some (toString i)
      | none => none
    else none
  else if s.startsWith "__koru_stdout_write_f64" then none
  else if s.startsWith "__koru_stdout_write" then
    let arg := s.drop "__koru_stdout_write".length
    if arg.startsWith "(\"" && arg.endsWith "\")" then
      cUnescape ((arg.drop 2 |>.dropEnd 2).copy.toList)
    else none
  else none

/-- The stdout a `koru_flow_*` body commits: every statement must be a
recognized write; anything else refuses. -/
def cBodyWrites (body : String) : Option String :=
  ((body.splitOn ";").mapM cStmtText).map (String.join ·)

/-- `main`'s ordered `koru_flow_N()` calls — the execution order the
claims must zip against. Subset is a flat statement list; `return …`
terminates. -/
def cMainCalls (src : String) : Option (List String) :=
  match src.splitOn "int main" with
  | [_, rest] =>
      match rest.splitOn "{" with
      | _ :: bodyAndAfter :: _ =>
          match bodyAndAfter.splitOn "}" with
          | body :: _ =>
              ((body.splitOn ";").mapM fun (st : String) =>
                let s := st.trimAscii.copy
                if s.isEmpty then some none
                else if s.startsWith "return" then some none
                else if s.startsWith "koru_flow_" && s.endsWith "()" then
                  some (some (s.dropEnd 2).copy)
                else none).map (·.filterMap id)
          | [] => none
      | _ => none
  | _ => none

/-- One `static void NAME(void) { … }` body — flat-body subset: nested
braces truncate the slice, whose statements then refuse to parse. -/
def cFnBody (src : String) (name : String) : Option String :=
  match src.splitOn ("static void " ++ name ++ "(void)") with
  | [_, rest] =>
      match rest.splitOn "{" with
      | _ :: bodyAndAfter :: _ =>
          match bodyAndAfter.splitOn "}" with
          | body :: _ => some body
          | [] => none
      | _ => none
  | _ => none

/-- The A.5 verdict over one claim stream: zip claims against `main`'s
ordered flow calls; per pair, the kernel-rendered observable must equal
the C body's writes. `none` = outside the subset (count mismatch,
`refuse` claim, unrenderable residue, unparseable C); `some false` =
a decided mismatch — the emitter's writes and the kernel's render
disagree. -/
def checkCRefine : List Claim → List String → String → Option Bool
  | [], [], _ => some true
  | c :: cs, fn :: fns, src =>
      match c.expected with
      | none => none
      | some r =>
          match renderObservable c.residue r,
                (cFnBody src fn).bind cBodyWrites with
          | some want, some got =>
              if want == got then checkCRefine cs fns src else some false
          | _, _ => none
  | _, _, _ => none

def cRefineAll (claims : List Claim) (src : String) : Option Bool :=
  match cMainCalls src with
  | none => none
  | some fns => checkCRefine claims fns src

/-! ## Corpus driver -/

def isClaimLine (line : String) : Bool :=
  line.startsWith "[flow-eval] "

/-- Byte-identical claims appearing twice inflate a claimed count
without adding coverage — a drift violation. Reported once each. -/
def dupLines : List String → List String → List String
  | [], _ => []
  | x :: rest, seen =>
      if x ∉ seen && x ∈ rest then x :: dupLines rest (x :: seen)
      else dupLines rest (x :: seen)

def parseArgs : List String → Option (Bool × Option String × String)
  | ["--forged", p] => some (true, none, p)
  | ["--cref", c, p] => some (false, some c, p)
  | [p] => some (false, none, p)
  | _ => none

def main (args : List String) : IO UInt32 := do
  let some (forged, cpath, path) := parseArgs args
    | do IO.eprintln "usage: FlowCheck [--forged | --cref <emitted.c>] <corpus>"; return 2
  let raw := (← IO.FS.lines path).toList.filter isClaimLine
  if raw.isEmpty then
    IO.println s!"FAIL: no [flow-eval] lines in {path}"
    return 1
  let lines := raw.map fun l => (l.drop "[flow-eval] ".length).toString
  let mut bad := 0
  for (line, sexpr) in raw.zip lines do
    let verdict := checkLine sexpr
    let accepted := verdict == some true
    let label := match verdict with
      | some true => "MATCH"
      | some false => "MISMATCH (re-decided differently)"
      | none => "MALFORMED"
    let ok := if forged then !accepted else accepted
    if !ok then bad := bad + 1
    IO.println s!"{if ok then "ok  " else "BAD "} {label}  {line}"
  for d in dupLines lines [] do
    if !forged then bad := bad + 1
    IO.println s!"{if forged then "ok  " else "BAD "} DUPLICATE  {d}"
  if let some cp := cpath then
    let csrc ← IO.FS.readFile cp
    match (lines.map fun s => (parseTop s).bind sxClaim).mapM id with
    | none =>
        bad := bad + 1
        IO.println "BAD  cref: SKIP — a claim line did not decode"
    | some claims =>
        match cRefineAll claims csrc with
        | some true =>
            IO.println "cref: refined — kernel-rendered stdout == emitted C writes"
        | some false =>
            bad := bad + 1
            IO.println "BAD  cref: MISMATCH — C writes ≠ kernel render"
        | none =>
            bad := bad + 1
            IO.println "BAD  cref: outside-subset — claim's residue or the C body is outside the rendered subset"
  let mode := if forged then "forged (all must reject)" else "conformance (all must match)"
  IO.println s!"{mode}: {raw.length} lines, {bad} bad"
  return (if bad == 0 then 0 else 1)

end Koru.FlowCheck

/-! ## End-to-end fixtures — text → parse → decode → re-decide, all
checked by the Lean kernel itself. These pin the wire format against
the kernel fixtures: the same programs the FlowKernel fixtures
evaluate must decode to identical verdicts as wire text. -/

namespace Koru.FlowCheck
open Koru.FlowKernel

/-- The gArith fixture as wire text — a nested-invocation chain whose
asserted result must re-decide exactly. -/
theorem wire_arith : checkLine "((entry main) (fuel 16) (result (bare (int 20))) (graph (def add (bare (bin add (var a) (var b)))) (def mul (bare (bin mul (var x) (var y)))) (def main (subflow (head add (a (lit (int 2))) (b (lit (int 3)))) (arm (tag go) (bind s) (node (invoke mul (x (var s)) (y (lit (int 4))))) (conts (arm (tag done) (bind t) (node (produce (var t))))))))) (oracle))" == some true := by native_decide

/-- A thunk-oracle claim — asserted leaf, kernel-decided dispatch. -/
theorem wire_thunk : checkLine "((entry main) (fuel 16) (result (bare (int 5))) (graph (def tick thunk) (def main (subflow (head tick (n (lit (int 5)))) (arm (tag go) (bind i) (node (produce (var i))))))) (oracle (leaf tick ((n (int 5))) (tag go (int 5)))))" == some true := by
  native_decide

/-- A `refuse` claim must hold only when eval genuinely does not
decide — unasserted thunk, generous fuel. -/
theorem wire_refuse : checkLine "((entry main) (fuel 64) (result refuse) (graph (def tick thunk) (def main (subflow (head tick (n (lit (int 5)))) (arm (tag go) (bind i) (node (produce (var i))))))) (oracle))" == some true := by native_decide

/-- The same claim with `refuse` on a program that DOES decide must
reject — not merely fail to match. -/
theorem wire_refuse_false : checkLine "((entry main) (fuel 64) (result refuse) (graph (def mk (bare (lit (int 0)))) (def main (subflow (head mk) (arm (tag x) (node terminal))))) (oracle))" == some false := by native_decide

/-- The labeled loop as wire text. -/
theorem wire_loop : checkLine "((entry count (n (int 5))) (fuel 64) (result (bare (int 0))) (graph (def dec (bare (bin sub (var n) (lit (int 1))))) (def count (subflow (label loop) (head dec (n (var n))) (arm (tag go) (bind i) (when (bin lt (lit (int 0)) (var i))) (node (jump loop (n (bin sub (var i) (lit (int 1))))))) (arm (tag go) (bind i) (node (produce (var i))))))) (oracle))" == some true := by native_decide

/-- `@as`'s lazy type argument survives the round trip — the claim
evaluates despite `i32` being an unbound name. -/
theorem wire_as_lazy : checkLine "((entry calc) (fuel 16) (result (bare (int -3))) (graph (def calc (bare (builtin as (var i32) (builtin divTrunc (lit (int -7)) (lit (int 2))))))) (oracle))" == some true := by native_decide

/-- Malformed inputs refuse at the decode layer, never silently. -/
theorem wire_malformed_paren :
    parseTop "((entry main) (fuel 8)" == none := by native_decide

theorem wire_malformed_op : checkLine "((entry f) (fuel 8) (result (bare (int 1))) (graph (def f (bare (bin pow (lit (int 1)) (lit (int 1)))))) (oracle))" == none := by native_decide

/-- A duplicated field refuses — `(fuel 1) (fuel 2)` is not a claim. -/
theorem wire_dup_field : checkLine "((entry f) (fuel 8) (fuel 9) (result (bare (int 1))) (graph (def f (bare (lit (int 1))))) (oracle))" == none := by
  native_decide

end Koru.FlowCheck

def main (args : List String) : IO UInt32 := Koru.FlowCheck.main args
