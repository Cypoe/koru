/-
FlowKernel — a mechanized kernel subset of the Koru flow-graph semantics.

This is the first rung of the audit's §6a path: the elaborated flow graph
is the shared boundary both emitters consume, so a mechanized evaluator
for a kernel subset is the anchor every later claim (emitted-C refines
graph, transform preserves meaning) needs a domain for.

Kernel scope, deliberately small:
  * values: i64 (`int`), `bool`, `unit`
  * expressions: literals, positional args, ambient bindings, binary ops,
    `ife` conditionals, `ret label payload` branch delivery
  * nodes: `invoke` (tor call + continuation list) and `halt` (tail expr)
  * continuations: branch label, optional when-clause, optional binding,
    next node — first match in list order wins
  * tors: arity + a pure expression body

What is NOT modeled: effects (`!` handlers), stores, labels, taps,
transforms, modules, name resolution, recursion. The corpus-facing leg
(emitting `graph-eval` claims for kernel-subset programs and re-deciding
them here) is the next rung; this file is the semantics alone, with its
own compile-time-checked fixture evaluations and metatheorems.

Honesty notes:
  * `evalNode` is fuel-bounded — the graph is a data structure, not a
    proof of termination, and fuel makes the evaluator total without
    pretending the object language is terminating. `evalNode_mono`
    proves more fuel never flips a decided result.
  * The evaluator is the *single* semantics; nothing else re-decides it.
    Any divergence between this evaluator and koruc's runtime behavior
    on kernel-subset programs is a bug in one of them — that is the
    point of having one mechanized definition.
-/

namespace Koru.FlowKernel

/-- Kernel values: the leaf types the kernel commits to. -/
inductive Val where
  | int : Int → Val
  | bool : Bool → Val
  | unit : Val
deriving DecidableEq, Repr

/-- What an invocation hands its continuations: the branch label it
terminated on plus the payload it delivered. Branch `""` is the
unconditional `|>` path — a tor body that evaluates to a plain value
delivers it there. -/
structure Result where
  branch : String
  payload : Val
deriving DecidableEq, Repr

/-- Two-sorted expression value: `val` flows through arithmetic;
`ret l v` is how a tor body says "I terminate on branch `l` with
payload `v`". -/
inductive EV where
  | val : Val → EV
  | ret : String → Val → EV
deriving Repr

inductive BinOp where
  | add | sub | mul | div | mod
  | eq | ne | lt | le
  | and | or
deriving DecidableEq, Repr

/-- Pure expressions. `arg i` reads the tor's i-th positional parameter
(encoded as the ambient name `_arg<i>` seeded at call time); `var s`
reads an ambient name bound by an enclosing continuation; `ret` is
a branch delivery and is a type error anywhere a plain value is
required. -/
inductive Expr where
  | lit : Val → Expr
  | arg : Nat → Expr
  | var : String → Expr
  | bin : BinOp → Expr → Expr → Expr
  | ife : Expr → Expr → Expr → Expr
  | ret : String → Expr → Expr
deriving DecidableEq, Repr

/-- A kernel tor: `arity` positional parameters and a pure body. -/
structure Tor where
  arity : Nat
  body : Expr
deriving Repr

mutual
/-- Flow nodes: `invoke` calls a tor and dispatches to the first firing
continuation; `halt` evaluates a tail expression and delivers on the
unconditional branch. -/
inductive Node where
  | halt : Expr → Node
  | invoke : String → List Expr → List Cont → Node
/-- A branch handler: fires when the invocation terminated on `branch`
AND `cond` (if present) evaluates to `bool true`. The payload binds
`bind` if present. -/
inductive Cont where
  | mk : (branch : String) → (cond : Option Expr) →
         (bind : Option String) → (next : Node) → Cont
end

/-- Field projections — a plain inductive does not synthesize them. -/
def Cont.branch : Cont → String | .mk b _ _ _ => b
def Cont.cond : Cont → Option Expr | .mk _ c _ _ => c
def Cont.bind : Cont → Option String | .mk _ _ b _ => b
def Cont.next : Cont → Node | .mk _ _ _ n => n

/-- The declaration table: name → tor. -/
abbrev Graph := List (String × Tor)

/-- Ambient bindings — tor params (as `_arg<i>`) and continuation-bound
names. Tor bodies evaluate under the parameter env ALONE: a body cannot
see the caller's bindings. -/
abbrev Env := List (String × Val)

def Env.lookup (e : Env) (s : String) : Option Val :=
  (e.find? (·.1 == s)).map (·.2)

def argEnv (args : List Val) : Env :=
  args.mapIdx fun i v => (s!"_arg{i}", v)

def evalBin : BinOp → Val → Val → Option Val
  | .add, .int a, .int b => some (.int (a + b))
  | .sub, .int a, .int b => some (.int (a - b))
  | .mul, .int a, .int b => some (.int (a * b))
  | .div, .int a, .int b => if b == 0 then none else some (.int (a / b))
  | .mod, .int a, .int b => if b == 0 then none else some (.int (a % b))
  | .eq, .int a, .int b => some (.bool (a == b))
  | .ne, .int a, .int b => some (.bool (a != b))
  | .lt, .int a, .int b => some (.bool (a < b))
  | .le, .int a, .int b => some (.bool (a ≤ b))
  | .eq, .bool a, .bool b => some (.bool (a == b))
  | .ne, .bool a, .bool b => some (.bool (a != b))
  | .and, .bool a, .bool b => some (.bool (a && b))
  | .or, .bool a, .bool b => some (.bool (a || b))
  | _, _, _ => none

/-- Evaluate a pure expression under an ambient env. Yields `val` for
ordinary results, `ret` for branch delivery; `ret` inside a position
that needs a plain value (bin operands, ife condition) is a type
error — `none`. -/
def evalE : Env → Expr → Option EV
  | _, .lit v => some (.val v)
  | env, .arg i => (env.lookup s!"_arg{i}").map .val
  | env, .var s => (env.lookup s).map .val
  | env, .bin op a b => do
      match ← evalE env a, ← evalE env b with
      | .val x, .val y => (evalBin op x y).map .val
      | _, _ => none
  | env, .ife c t e => do
      match ← evalE env c with
      | .val (.bool true) => evalE env t
      | .val (.bool false) => evalE env e
      | _ => none
  | env, .ret l p => do
      match ← evalE env p with
      | .val v => some (.ret l v)
      | _ => none

/-- Does this continuation fire for a delivered result? Branch must
match exactly, and a `when` clause must evaluate to `bool true` under
the env extended by the payload binding. A cond that fails to evaluate
is a program error — propagates as `none`, not a silent skip. -/
def Cont.fires (env : Env) (c : Cont) (r : Result) : Option Bool := do
  if c.branch != r.branch then return false
  match c.cond with
  | none => return true
  | some e =>
    let env' := match c.bind with
      | some b => (b, r.payload) :: env
      | none => env
    match ← evalE env' e with
    | .val (.bool b) => return b
    | _ => none

/-- First firing continuation in list order — `|>`'s left-to-right
branch dispatch. `none` when none fires or a `when` errors. -/
def firstCont (env : Env) : List Cont → Result → Option Cont
  | [], _ => none
  | c :: rest, r => do
    match ← c.fires env r with
    | true => return c
    | false => firstCont env rest r

/-- Evaluate a node. `invoke` evaluates arg expressions, evaluates the
tor's body under its parameter env, delivers `(branch, payload)` to the
first firing continuation, and evaluates that continuation's node under
the payload binding. `halt e` evaluates `e` and delivers its result — a
`ret` delivers its named branch, a plain value the unconditional one.

`fuel` bounds call depth — decrement on `invoke` only; `halt` and
continuation dispatch are free. -/
def evalNode (g : Graph) (env : Env) : (fuel : Nat) → Node → Option Result
  | 0, _ => none
  | _ + 1, .halt e => do
      match ← evalE env e with
      | .val x => return ⟨"", x⟩
      | .ret l p => return ⟨l, p⟩
  | fuel + 1, .invoke name argExprs conts => do
      let argEVs ← argExprs.mapM (evalE env)
      let argVals ← argEVs.mapM fun
        | .val v => some v
        | _ => none
      let tor ← g.lookup name
      let bodyV ← evalE (argEnv argVals) tor.body
      let r ← match bodyV with
        | .ret l p => some ⟨l, p⟩
        | .val v => some ⟨"", v⟩
      let c ← firstCont env conts r
      let env' := match c.bind with
        | some b => (b, r.payload) :: env
        | none => env
      evalNode g env' fuel c.next
termination_by fuel => fuel

/-- Evaluate a whole kernel program: `entry` node under the graph and an
empty ambient environment. `none` = type error, missing tor, unmatched
branch, or fuel exhausted — the evaluator never picks a "close enough"
answer. -/
def eval (g : Graph) (fuel : Nat) (entry : Node) : Option Result :=
  evalNode g [] fuel entry

/-! ## Fixtures — kernel programs with committed evaluations

Each `theorem` below is checked at compile time: `by decide` makes the
kernel itself compute the evaluator on the fixture and verify the
result — a proof, not a test that can be skipped. -/

/-- `add` and `mul` tors; entry chains them through continuation-bound
payloads: add(2,3) bound `s`, mul(s,4) bound `t`, halt on `t`. -/
def gArith : Graph :=
  [ ("add", ⟨2, .bin .add (.arg 0) (.arg 1)⟩)
  , ("mul", ⟨2, .bin .mul (.arg 0) (.arg 1)⟩) ]

def nArith : Node :=
  .invoke "add" [.lit (.int 2), .lit (.int 3)]
    [.mk "" none (some "s")
      (.invoke "mul" [.var "s", .lit (.int 4)]
        [.mk "" none (some "t") (.halt (.var "t"))])]

theorem eval_arith : eval gArith 8 nArith = some ⟨"", .int 20⟩ := by native_decide

/-- Branch selection: `classify` returns branch "neg" or "pos"; the
dispatch must pick the firing arm, not the first listed. -/
def gBranch : Graph :=
  [ ("classify", ⟨1, .ife (.bin .lt (.arg 0) (.lit (.int 0)))
                      (.ret "neg" (.lit (.int 0)))
                      (.ret "pos" (.arg 0))⟩) ]

def nBranch : Node :=
  .invoke "classify" [.lit (.int (-5))]
    [ .mk "pos" none none (.halt (.lit (.int 999)))
    , .mk "neg" none none (.halt (.lit (.int 7))) ]

theorem eval_branch_neg :
    eval gBranch 4 nBranch = some ⟨"", .int 7⟩ := by native_decide

/-- A `when` clause that evaluates false skips the continuation; the
same branch name fires on the next matcher. -/
def gWhen : Graph :=
  [ ("probe", ⟨0, .ret "out" (.lit (.int 5))⟩) ]

def nWhen : Node :=
  .invoke "probe" []
    [ .mk "out" (some (.bin .lt (.var "p") (.lit (.int 0)))) (some "p")
        (.halt (.lit (.int 0)))
    , .mk "out" none (some "p") (.halt (.var "p")) ]

theorem eval_when_skip : eval gWhen 4 nWhen = some ⟨"", .int 5⟩ := by native_decide

/-- No continuation fires → `none` (a missed branch is not unit). -/
def nNoMatch : Node :=
  .invoke "classify" [.lit (.int 3)]
    [ .mk "neg" none none (.halt (.lit (.int 0))) ]

theorem eval_nomatch : eval gBranch 4 nNoMatch = none := by native_decide

/-- Type errors are refusals, not coercions: `int + bool` fails. -/
def gBadType : Graph := [ ("bad", ⟨0, .bin .add (.lit (.int 1)) (.lit (.bool true))⟩) ]
def nBadType : Node := .invoke "bad" [] [ .mk "" none none (.halt (.lit .unit)) ]

theorem eval_typeerr : eval gBadType 4 nBadType = none := by native_decide

/-- Division by zero refuses. -/
def gDivZero : Graph := [ ("dv", ⟨0, .bin .div (.lit (.int 1)) (.lit (.int 0))⟩) ]
def nDivZero : Node := .invoke "dv" [] [ .mk "" none none (.halt (.lit .unit)) ]

theorem eval_divzero : eval gDivZero 4 nDivZero = none := by native_decide

/-- Fuel exhausts rather than diverging: a chain of 3 invokes needs
fuel ≥ 4. -/
def gChain : Graph := [ ("id", ⟨1, .arg 0⟩) ]
def nChain : Node :=
  .invoke "id" [.lit (.int 1)]
    [.mk "" none none
      (.invoke "id" [.lit (.int 2)]
        [.mk "" none none
          (.invoke "id" [.lit (.int 3)]
            [.mk "" none none (.halt (.lit (.int 9)))])])]

theorem eval_fuel_short : eval gChain 3 nChain = none := by native_decide
theorem eval_fuel_enough : eval gChain 4 nChain = some ⟨"", .int 9⟩ := by native_decide

/-- A terminal `ret` delivers its named branch as the program's result,
not a type error — the branch label is part of what evaluation means. -/
def nHaltRet : Node := .halt (.ret "done" (.lit (.int 42)))

theorem eval_halt_ret : eval [] 2 nHaltRet = some ⟨"done", .int 42⟩ := by native_decide

/-! ## Metatheorems -/

/-- Branch dispatch really is first-match: if every continuation in
`pre` fails to fire and `c` fires, `firstCont` returns `c`. -/
theorem firstCont_fires_first (env : Env) (r : Result) :
    ∀ (pre : List Cont) (c : Cont) (post : List Cont),
    (∀ c' ∈ pre, c'.fires env r = some false) →
    c.fires env r = some true →
    firstCont env (pre ++ c :: post) r = some c := by
  intro pre
  induction pre with
  | nil =>
    intro c post _ hc
    simp [firstCont, hc]
  | cons h t ih =>
    intro c post hpre hc
    have h0 : h.fires env r = some false := hpre h List.mem_cons_self
    have hrest : ∀ c' ∈ t, c'.fires env r = some false :=
      fun c' hm => hpre c' (List.mem_cons_of_mem _ hm)
    simp only [List.cons_append, firstCont, h0]
    exact ih c post hrest hc

/-- Fuel monotonicity: once a node evaluates, more fuel cannot change
the result. This is why fuel-bounded evaluation is safe — `none` at a
given fuel means "undecided or failing", never "computed differently". -/
theorem evalNode_mono (g : Graph) :
    ∀ (env : Env) (fuel : Nat) (n : Node) (r : Result),
    evalNode g env fuel n = some r →
    evalNode g env (fuel + 1) n = some r := by
  intro env fuel
  induction fuel generalizing env with
  | zero =>
    intro n r h
    rw [evalNode] at h
    exact nomatch h
  | succ f ih =>
    intro n r h
    cases n with
    | halt e =>
      rw [evalNode] at h ⊢
      exact h
    | invoke name args conts =>
      rw [evalNode] at h ⊢
      -- both sides are the same bind chain; only the last evalNode call
      -- carries a different fuel. Unpack each Option.bind into its
      -- existential shape; the shared prefix gives the witnesses, the
      -- IH discharges the final call.
      simp only [Option.bind_eq_bind, Option.bind_eq_some_iff] at h ⊢
      obtain ⟨x1, h1, x2, h2, t, ht, bv, hbv, htail⟩ := h
      refine ⟨x1, h1, x2, h2, t, ht, bv, hbv, ?_⟩
      cases bv with
      | ret l p =>
        simp only [Option.bind_eq_some_iff] at htail ⊢
        obtain ⟨y, hy, c, hc, hcall⟩ := htail
        exact ⟨y, hy, c, hc, ih _ _ _ hcall⟩
      | val v =>
        simp only [Option.bind_eq_some_iff] at htail ⊢
        obtain ⟨y, hy, c, hc, hcall⟩ := htail
        exact ⟨y, hy, c, hc, ih _ _ _ hcall⟩

end Koru.FlowKernel
