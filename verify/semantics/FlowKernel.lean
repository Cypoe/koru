/-
FlowKernel — a mechanized kernel subset of the Koru flow semantics.

This is the first rung of the audit's §6a path: the flow walker in
`src/comptime_eval.zig` is the reference operational semantics ("the
runtime's arm semantics, interpreted"), and this file is its faithful
kernel subset — checked against that source, not invented.

Semantic fidelity (mapped from comptime_eval.zig, rung-two walker):

  * A call result is a THREE-CASE thing: tagged `{branch, payload}`,
    a bare `-> T` return `{none, some v}`, or void `{none, none}`.
    These dispatch differently — they are not one case with "".
  * Tagged dispatch: arms are scanned in order; only arms whose name
    equals the branch are eligible (catchall and unnamed arms are
    skipped); the first arm whose guard passes fires. Payload binds
    BEFORE the guard evaluates, so `when` sees it.
  * Bare `-> T` dispatch: arm names are decorative — every arm is a
    candidate in order and the guard selects; encountering a catchall
    or unnamed arm REFUSES (the walker fails loudly).
  * Void results cannot dispatch at all — void + arms is a refusal.
  * Arm nodes: `terminal` (chain ends, void), `@label(args)` jump,
    chained invocation (with nested arms), `=> branch value`
    constructor (produces a tagged result), `-> expr` produce
    (produces a bare result).
  * `#label` flows: an arm chain may end in `@label(...)`; the jump
    re-enters the flow's head invocation with the jump's evaluated
    arguments. The call env (flow's own args) does NOT change.
  * Resolution order: thunk (native — modeled as an asserted oracle
    leaf) → subflow implementation → bare-return impl.
  * Callee envs are FRESH: a flow body sees its own arguments, never
    the caller's bindings. Arm envs are children: payload bindings
    shadow, outer names still visible.
  * All args are NAMED and evaluated at the call site.

What is NOT modeled (serialization refuses rather than guesses):
effects/`!` handlers, stores, residual catchall metatypes, destructured
arms, `Source` args, `fragment` values, function calls (the WALKER
refuses them too — they need the source-time call bridge), nested
labels (a jump to a label other than the enclosing `#label` refuses,
matching the walker), module path resolution (names are last-segment).
Integer width: `Val.int` is unbounded `Int`; the walker's i64 overflow
wrap is not modeled.

Fuel: every `run` step costs one unit — fuel bounds total evaluator
steps, not call depth. `run_mono` proves more fuel never flips a
decided result, so a fuel bound is a resource cap, not a semantics
change. The comptime walker's `WALK_ITERATION_WALL` is the same move
with a bigger number.

Honesty note: this kernel is a SINGLE definition, not a re-decider —
divergence between this evaluator and the walker is a bug in one of
them; that is what the corpus-facing leg (FlowCheck) exists to catch.
-/

namespace Koru.FlowKernel

/-- Kernel values — the walker's `Value` union minus `fragment` (rung
one never produces it; serialization refuses it). `cell` is the
walker's `*Cell` record; comptime evaluation never mutates cells, so a
list of fields is faithful (lookups take the LAST binding, matching
`put`-overwrite semantics). -/
inductive Val where
  | int : Int → Val
  | float : Float → Val
  | bool : Bool → Val
  | str : String → Val
  | arr : List Val → Val
  | cell : List (String × Val) → Val
deriving BEq, Repr

/-- What one call produced — `ThunkResult`. Three honest cases:
tagged `{some b, payload}`, bare `{none, some v}`, void `{none, none}`. -/
structure Result where
  branch : Option String := none
  payload : Option Val := none
deriving BEq, Repr

inductive BinOp where
  | add | sub | mul | div | mod
  | eq | ne | lt | le | gt | ge
  | and | or
  | concat
deriving DecidableEq, BEq, Repr

inductive UnOp where
  | not | neg
deriving DecidableEq, BEq, Repr

/-- Pure expressions — the walker's full `ExprNode` surface that can
evaluate: literal, identifier, binary, unary, conditional, field
access (cells), array indexing, and the builtin table. `grouped`
vanishes at parse; `function_call` is refused by the WALKER itself
(needs the source-time call bridge), so the kernel's serializer
refuses it the same way. -/
inductive Expr where
  | lit : Val → Expr
  | var : String → Expr
  | bin : BinOp → Expr → Expr → Expr
  | un : UnOp → Expr → Expr
  | cond : Expr → Expr → Expr → Expr
  | field : Expr → String → Expr
  | index : Expr → Expr → Expr
  | builtin : String → List Expr → Expr
deriving BEq, Repr

/-- Arm node kinds — the walker's `arm.node` switch, minus refused
variants (destructured arms, etc. are serialized as refusals, not
modeled). `jump` is `@label(args)`; `invoke` chains a call under this
arm with nested continuations; `retCtor` is `=> branch value`;
`produce` is `-> expr` (a bare, tagless result). -/
inductive ArmNode where
  | terminal : ArmNode
  | jump : String → List (String × Expr) → ArmNode
  | invoke : String → List (String × Expr) → ArmNode
  | produce : Expr → ArmNode
  | retCtor : String → Expr → ArmNode
deriving Repr

/-- A `| branch bind? when? |> node` arm. `catchall` marks `|*`-style
residual arms — present in the model only so dispatch can skip/refuse
them the way the walker does. `node` absent = chain ends (walker's
`arm.node orelse return .none`). `conts` are the arms nested under an
`invoke` node. -/
structure Arm where
  branch : String := ""
  catchall : Bool := false
  bind : Option String := none
  cond : Option Expr := none
  node : Option ArmNode := none
  conts : List Arm := []
deriving Repr

/-- A walkable flow implementation: optional `#label`, a head invocation
(the walker refuses non-invocation heads), and the arm list. -/
structure Flow where
  preLabel : Option String := none
  head : String × List (String × Expr)
  arms : List Arm := []
deriving Repr

/-- The declaration table, in the walker's resolution order:
thunk = native callable (the kernel cannot evaluate it — its calls
are resolved through the asserted-call oracle instead);
bare = `impl of name { -> expr }`, a bare-return impl;
subflow = a walkable flow implementation. -/
inductive Callable where
  | thunk : Callable
  | bare : Expr → Callable
  | subflow : Flow → Callable
deriving Repr

abbrev Graph := List (String × Callable)

/-- Asserted call leaves: thunk/native calls the kernel cannot evaluate
are committed in the corpus as `(name, args) → result` claims. This is
the declared trust boundary of the corpus leg — control flow around the
leaves is re-decided; the leaf values are asserted by the emitter. -/
abbrev Oracle := List ((String × List (String × Val)) × Result)

abbrev Env := List (String × Val)

def Env.lookup (e : Env) (s : String) : Option Val :=
  (e.find? (·.1 == s)).map (·.2)

/-- Named args bound in a fresh scope — `walkFlow`'s `env.bind`. -/
def argEnv (args : List (String × Val)) : Env := args

/-- Truncating integer division — `@divTrunc`, the C-parity choice the
walker documents. Lean's `/` floors; `-7 / 2` is `-3` here, `-4` floored. -/
def tdiv (a b : Int) : Int :=
  let q : Int := a.natAbs / b.natAbs
  if (a < 0) == (b < 0) then q else -q

/-- C-style remainder — `@rem`; sign follows the dividend. -/
def tmod (a b : Int) : Int := a - b * tdiv a b

/-- Floored remainder — Zig `@mod`, sign follows the divisor (`fdiv`
floors). -/
def fmod (a b : Int) : Int := a - b * a.fdiv b

/-- Float truncation toward zero — `floor` for positive, `ceil` for
negative. -/
def ftrunc (x : Float) : Float := if x < 0 then x.ceil else x.floor

/-- Float remainder — `@rem` on floats is fmod: `a - b * trunc(a/b)`. -/
def frem (a b : Float) : Float := a - b * ftrunc (a / b)

/-- `asFloat` — int promotes to float; anything else is a TypeMismatch. -/
def asFloat : Val → Option Float
  | .float f => some f
  | .int i => some (Float.ofInt i)
  | _ => none

/-- The float arm of the numeric tower — any float operand promotes
both. `/` and `%` carry no zero check (IEEE semantics, like the walker). -/
def floatBin : BinOp → Float → Float → Option Val
  | .add, a, b => some (.float (a + b))
  | .sub, a, b => some (.float (a - b))
  | .mul, a, b => some (.float (a * b))
  | .div, a, b => some (.float (a / b))
  | .mod, a, b => some (.float (frem a b))
  | .eq, a, b => some (.bool (a == b))
  | .ne, a, b => some (.bool (a != b))
  | .lt, a, b => some (.bool (a < b))
  | .le, a, b => some (.bool (a ≤ b))
  | .gt, a, b => some (.bool (a > b))
  | .ge, a, b => some (.bool (a ≥ b))
  | _, _, _ => none

def evalBin : BinOp → Val → Val → Option Val
  -- Numeric tower: a float on either side promotes both (`asFloat`
  -- refuses non-numbers → TypeMismatch).
  | op, .float fa, b => (asFloat b).bind (floatBin op fa)
  | op, a, .float fb => (asFloat a).bind fun af => floatBin op af fb
  | .add, .int a, .int b => some (.int (a + b))
  | .sub, .int a, .int b => some (.int (a - b))
  | .mul, .int a, .int b => some (.int (a * b))
  | .div, .int a, .int b => if b == 0 then none else some (.int (tdiv a b))
  | .mod, .int a, .int b => if b == 0 then none else some (.int (tmod a b))
  | .eq, .int a, .int b => some (.bool (a == b))
  | .ne, .int a, .int b => some (.bool (a != b))
  | .lt, .int a, .int b => some (.bool (a < b))
  | .le, .int a, .int b => some (.bool (a ≤ b))
  | .gt, .int a, .int b => some (.bool (a > b))
  | .ge, .int a, .int b => some (.bool (a ≥ b))
  | .eq, .bool a, .bool b => some (.bool (a == b))
  | .ne, .bool a, .bool b => some (.bool (a != b))
  | .eq, .str a, .str b => some (.bool (a == b))
  | .ne, .str a, .str b => some (.bool (a != b))
  | .concat, .str a, .str b => some (.str (a ++ b))
  | _, _, _ => none

def evalUn : UnOp → Val → Option Val
  | .not, .bool b => some (.bool !b)
  | .neg, .int i => some (.int (-i))
  | .neg, .float f => some (.float (-f))
  | _, _ => none

mutual
/-- Evaluate a pure expression. `and`/`or`/`cond` short-circuit the way
`evalBinary`/`evalNode` do — the undecided side never evaluates, so
`false and <error>` is `false`, not a refusal. Field access resolves
on cells only (last binding wins, `put`-overwrite parity); indexing
needs an array and an in-range int index. -/
def evalE : Env → Expr → Option Val
  | _, .lit v => some v
  | env, .var s => env.lookup s
  | env, .bin .and a b =>
      match evalE env a with
      | some (.bool false) => some (.bool false)
      | some (.bool true) =>
          match evalE env b with
          | some (.bool r) => some (.bool r)
          | _ => none
      | _ => none
  | env, .bin .or a b =>
      match evalE env a with
      | some (.bool true) => some (.bool true)
      | some (.bool false) =>
          match evalE env b with
          | some (.bool r) => some (.bool r)
          | _ => none
      | _ => none
  | env, .cond c t e =>
      match evalE env c with
      | some (.bool true) => evalE env t
      | some (.bool false) => evalE env e
      | _ => none
  | env, .field obj name =>
      match evalE env obj with
      | some (.cell fields) =>
          (fields.reverse.find? (·.1 == name)).map (·.2)
      | _ => none
  | env, .index obj idx =>
      match evalE env obj, evalE env idx with
      | some (.arr items), some (.int i) =>
          if i < 0 || items.length ≤ i.toNat then none else items[i.toNat]?
      | _, _ => none
  | env, .builtin name args => evalBuiltin env name args
  | env, .bin op a b =>
      match evalE env a, evalE env b with
      | some x, some y => evalBin op x y
      | _, _ => none
  | env, .un op a =>
      match evalE env a with
      | some x => evalUn op x
      | _ => none

/-- The builtin table over UNEVALUATED args — the walker decides by
name first, then evaluates only the argument positions it needs
(`@as`'s type name is ignored, never evaluated — `@as(i32, 5)`
evaluates even though `i32` is not a value). Arity is checked by the
match; anything else is `UnsupportedBuiltin`. -/
def evalBuiltin (env : Env) (name : String) (args : List Expr) : Option Val :=
  match name, args with
  | "as", [_, v] => evalE env v
  | "intCast", [e] =>
      match evalE env e with
      | some (.int i) => some (.int i)
      | _ => none
  | "truncate", [e] =>
      match evalE env e with
      | some (.int i) => some (.int i)
      | _ => none
  | "divTrunc", [ea, eb] =>
      match evalE env ea, evalE env eb with
      | some (.int a), some (.int b) =>
          if b == 0 then none else some (.int (tdiv a b))
      | _, _ => none
  | "rem", [ea, eb] =>
      match evalE env ea, evalE env eb with
      | some (.int a), some (.int b) =>
          if b == 0 then none else some (.int (tmod a b))
      | _, _ => none
  | "mod", [ea, eb] =>
      match evalE env ea, evalE env eb with
      | some (.int a), some (.int b) =>
          if b == 0 then none else some (.int (fmod a b))
      | _, _ => none
  | _, _ => none
end

def evalArgs (env : Env) : List (String × Expr) → Option (List (String × Val))
  | [] => some []
  | (n, e) :: rest => do
      let v ← evalE env e
      let vs ← evalArgs env rest
      return (n, v) :: vs

/-- What a dispatch or arm walk produced. `done` is the walker's
`.none` outcome — a terminal arm, chain ended, no result (the caller
turns it into a void `Result`). `skip` is internal: an arm's guard
rejected it and the dispatcher keeps scanning; it never escapes
`run`'s dispatch arms. -/
inductive Outcome where
  | result : Result → Outcome
  | jump : String → List (String × Val) → Outcome
  | done : Outcome
  | skip : Outcome
deriving BEq, Repr

/-- Evaluator tasks — one function so termination and monotonicity
are single inductions. `invoke` resolves and calls a name; `flow`
enters a subflow impl (fresh env, head args evaluated once);
`loop` is one labeled-body iteration; `dispatchTag`/`dispatchBare`
are the two arm-scanning conventions; `armTry` binds+guards+walks
one arm (`skip` when the guard rejects); `armWalk` runs a matched
arm's node. -/
inductive Call where
  | invoke : String → List (String × Val) → Call
  | flow : Flow → List (String × Val) → Call
  | loop : Flow → Env → List (String × Val) → Call
  | dispatchTag : Env → List Arm → String → Result → Call
  | dispatchBare : Env → List Arm → Result → Call
  | armTry : Env → Arm → Result → Call
  | armWalk : Env → Arm → Result → Call
deriving Repr

/-- Unwrap a nested call's outcome to its `Result` — inner refusals
propagate, and a non-result outcome where a result is required
(e.g. a jump escaping the arm that produced it) is malformed. -/
def asResult : Option Outcome → Option Result
  | some (.result r) => some r
  | _ => none

def Graph.lookup (g : Graph) (name : String) : Option Callable :=
  (g.find? (·.1 == name)).map (·.2)

def Oracle.lookup (o : Oracle) (name : String) (args : List (String × Val)) : Option Result :=
  (o.find? (fun ((n, as), _) => n == name && as == args)).map (·.2)

/-- Bind an arm's payload into the flow env — `matchArm`'s binding step.
A binding arm on a payload-less result refuses. -/
def bindArmEnv (a : Arm) (env : Env) (r : Result) : Option Env :=
  match a.bind with
  | some b => r.payload.map fun v => (b, v) :: env
  | none => some env

/-- Evaluate an arm's `when` guard under the bound env. No guard is
`true`; a guard that errors or yields non-bool refuses (the walker's
expectBool), `false` skips. -/
def evalGuard (env : Env) (a : Arm) : Option Bool :=
  match a.cond with
  | none => some true
  | some c =>
      match evalE env c with
      | some (.bool b) => some b
      | _ => none

/-- One evaluator step — every call costs one fuel. Mirrors the walker:

  * `invoke`: thunk → asserted oracle leaf; bare → evaluate the impl's
    expression under a fresh named-arg env (result is bare); subflow →
    enter the flow. Unknown name refuses.
  * `flow`: fresh env of call args, head arg exprs evaluated once in
    that env, enter the labeled loop.
  * `loop`: invoke the head with CURRENT head args; no arms → the
    call's raw result; else dispatch. `jump` to the flow's own label
    re-enters with the jump's args (flow env unchanged); any other
    label refuses — the walker's nested-label wall.
  * `dispatchTag`: scan in order; skip catchall/unnamed/wrong-name
    arms; `armTry` guard-rejects keep scanning; no match refuses.
  * `dispatchBare`: every arm is a candidate in order; encountering a
    catchall or unnamed arm refuses outright; `skip` keeps scanning.
  * `armTry`: bind payload (a binding arm on a payload-less result
    refuses), evaluate the guard under the bound env — a guard that
    errors or is not bool refuses (expectBool), a false guard skips —
    then walk the arm.
  * `armWalk`: terminal/missing node → `done`; `jump` → evaluated
    jump; `invoke` → chain result, dispatching nested arms when
    present; `produce`/`retCtor` → construct the result. -/
def run (g : Graph) (o : Oracle) : (fuel : Nat) → Call → Option Outcome
  | 0, _ => none
  | fuel + 1, .invoke name args =>
      match g.lookup name with
      | some .thunk => (o.lookup name args).map .result
      | some (.bare e) =>
          (evalE (argEnv args) e).map fun v =>
            .result { branch := none, payload := some v }
      | some (.subflow fl) => run g o fuel (.flow fl args)
      | none => none
  | fuel + 1, .flow fl callArgs =>
      match evalArgs (argEnv callArgs) fl.head.2 with
      | none => none
      | some hargs => run g o fuel (.loop fl (argEnv callArgs) hargs)
  | fuel + 1, .loop fl env hargs =>
      match run g o fuel (.invoke fl.head.1 hargs) with
      | some (.result r) =>
          if fl.arms.isEmpty then some (.result r)
          else
            match r.branch with
            | some b =>
                match run g o fuel (.dispatchTag env fl.arms b r) with
                | none => none
                | some (.result rr) => some (.result rr)
                | some .done => some (.result {})
                | some (.jump lbl jargs) =>
                    if fl.preLabel == some lbl
                    then run g o fuel (.loop fl env jargs)
                    else none
                | some .skip => none
            | none =>
                match run g o fuel (.dispatchBare env fl.arms r) with
                | none => none
                | some (.result rr) => some (.result rr)
                | some .done => some (.result {})
                | some (.jump lbl jargs) =>
                    if fl.preLabel == some lbl
                    then run g o fuel (.loop fl env jargs)
                    else none
                | some .skip => none
      | _ => none
  | fuel + 1, .dispatchTag env arms b r =>
      match arms with
      | [] => none
      | a :: rest =>
          -- The walker matches on name equality alone (`arm.branch ==
          -- branch`): catchall arms carry `*` and unnamed arms `""`, so
          -- neither can equal a produced tag. The flag matters only in
          -- bare dispatch, where the walker checks it explicitly.
          if a.branch != b
          then run g o fuel (.dispatchTag env rest b r)
          else
            match run g o fuel (.armTry env a r) with
            | none => none
            | some .skip => run g o fuel (.dispatchTag env rest b r)
            | some o1 => some o1
  | fuel + 1, .dispatchBare env arms r =>
      -- `dispatchArms`' first act on a tagless result: a VOID call cannot
      -- dispatch at all — refuse before scanning. The scan itself:
      -- every arm is a candidate in order; a catchall or unnamed arm
      -- refuses outright; `skip` keeps scanning.
      match r.payload with
      | none => none
      | some _ =>
          match arms with
          | [] => none
          | a :: rest =>
              if a.catchall || a.branch == ""
              then none
              else
                match run g o fuel (.armTry env a r) with
                | none => none
                | some .skip => run g o fuel (.dispatchBare env rest r)
                | some o1 => some o1
  | fuel + 1, .armTry env a r =>
      match bindArmEnv a env r with
      | none => none
      | some env' =>
          match evalGuard env' a with
          | none => none
          | some passes =>
              if passes then run g o fuel (.armWalk env' a r) else some .skip
  | fuel + 1, .armWalk env a _ =>
      match a.node with
      | none => some .done
      | some .terminal => some .done
      | some (.jump lbl aexprs) =>
          (evalArgs env aexprs).map (.jump lbl)
      | some (.invoke name aexprs) =>
          match evalArgs env aexprs with
          | none => none
          | some hargs =>
              match run g o fuel (.invoke name hargs) with
              | some (.result r) =>
                  if a.conts.isEmpty then some (.result r)
                  else run g o fuel (match r.branch with
                    | some b => .dispatchTag env a.conts b r
                    | none => .dispatchBare env a.conts r)
              | _ => none
      | some (.produce e) =>
          (evalE env e).map fun v => .result { branch := none, payload := some v }
      | some (.retCtor b e) =>
          (evalE env e).map fun v => .result { branch := some b, payload := some v }

/-- Evaluate a whole kernel program: entry call `name(args)` under the
graph and the asserted-call oracle. `none` = refusal: unknown callable,
missing asserted leaf, unhandled branch, guard/type error, or fuel
exhausted — the evaluator never picks a "close enough" answer. -/
def eval (g : Graph) (o : Oracle) (fuel : Nat) (name : String)
    (args : List (String × Val)) : Option Result :=
  asResult (run g o fuel (.invoke name args))

/-! ## Fixtures — kernel programs with committed evaluations

Each `theorem` is checked at compile time: `native_decide` makes the
kernel itself evaluate the fixture and verify the result — a proof,
not a test that can be skipped. -/

/-- Bare-return impls chained through untagged dispatch: add(a:2,b:3)
binds `s` via a decorative-named arm (bare convention: guards select,
names ignored), mul(x:s,y:4) binds `t`, `-> t` produces. -/
def gArith : Graph :=
  [ ("add", .bare (.bin .add (.var "a") (.var "b")))
  , ("mul", .bare (.bin .mul (.var "x") (.var "y")))
  , ("main", .subflow {
      head := ("add", [("a", .lit (.int 2)), ("b", .lit (.int 3))])
      arms := [
        { branch := "go", bind := some "s",
          node := some (.invoke "mul" [("x", .var "s"), ("y", .lit (.int 4))]),
          conts := [
            { branch := "done", bind := some "t",
              node := some (.produce (.var "t")) } ] } ] }) ]

theorem eval_arith :
    eval gArith [] 16 "main" [] == some { branch := none, payload := some (.int 20) } := by
  native_decide

/-- Tagged dispatch: `classify` is a subflow whose untagged head result
is steered by guards into `=> pos p` / `=> neg 0` constructors; the
caller's arms then match by branch name — first NAME match wins, and
the arm listed first but named wrong never fires. -/
def gBranch : Graph :=
  [ ("sign", .bare (.bin .lt (.var "x") (.lit (.int 0))))
  , ("classify", .subflow {
      head := ("sign", [("x", .var "x")])
      arms := [
        { branch := "ok", bind := some "p",
          cond := some (.var "p"),
          node := some (.retCtor "neg" (.lit (.int 0))) },
        { branch := "ok", bind := some "p",
          node := some (.retCtor "pos" (.var "x")) } ] })
  , ("main", .subflow {
      head := ("classify", [("x", .lit (.int (-5)))])
      arms := [
        { branch := "pos", node := some (.produce (.lit (.int 999))) },
        { branch := "neg", node := some (.produce (.lit (.int 7))) } ] }) ]

theorem eval_branch_neg :
    eval gBranch [] 32 "main" [] == some { branch := none, payload := some (.int 7) } := by
  native_decide

/-- Guard-skip on same-named arms: a `when` that evaluates false keeps
scanning same-named arms; the next matcher fires. -/
def gWhen : Graph :=
  [ ("probe", .subflow {
      head := ("five", [])
      arms := [
        { branch := "out", bind := some "p",
          cond := some (.bin .lt (.var "p") (.lit (.int 0))),
          node := some (.produce (.lit (.int 0))) },
        { branch := "out", bind := some "p",
          node := some (.produce (.var "p")) } ] })
  , ("five", .subflow {
      head := ("mk", [])
      arms := [ { branch := "out",
                  node := some (.retCtor "out" (.lit (.int 5))) } ] })
  , ("mk", .bare (.lit (.int 0))) ]

theorem eval_when_skip :
    eval gWhen [] 32 "probe" [] == some { branch := none, payload := some (.int 5) } := by
  native_decide

/-- No name-matching arm on a tagged result → refusal. -/
def nNoMatch : Flow := {
  head := ("classify", [("x", .lit (.int 3))])
  arms := [ { branch := "neg", node := some (.produce (.lit (.int 0))) } ] }

theorem eval_nomatch : run gBranch [] 32 (.flow nNoMatch []) == none := by
  native_decide

/-- Type errors are refusals, not coercions: `int + bool` fails. -/
def gBadType : Graph := [ ("bad", .bare (.bin .add (.lit (.int 1)) (.lit (.bool true)))) ]

theorem eval_typeerr : eval gBadType [] 8 "bad" [] == none := by native_decide

/-- Division by zero refuses. -/
def gDivZero : Graph := [ ("dv", .bare (.bin .div (.lit (.int 1)) (.lit (.int 0)))) ]

theorem eval_divzero : eval gDivZero [] 8 "dv" [] == none := by native_decide

/-- The labeled-loop countdown, in the real walker's shape: head calls
`dec` (a bare impl `n - 1`), whose bare result dispatches by guards —
`go i when i > 0` jumps back to `#loop` with `n: i - 1`, the unguarded
`go i` arm produces the final value. -/
def gCount : Graph :=
  [ ("dec", .bare (.bin .sub (.var "n") (.lit (.int 1))))
  , ("count", .subflow {
      preLabel := some "loop"
      head := ("dec", [("n", .var "n")])
      arms := [
        { branch := "go", bind := some "i",
          cond := some (.bin .lt (.lit (.int 0)) (.var "i")),
          node := some (.jump "loop" [("n", .bin .sub (.var "i") (.lit (.int 1)))]) },
        { branch := "go", bind := some "i",
          node := some (.produce (.var "i")) } ] }) ]

theorem eval_count :
    eval gCount [] 64 "count" [("n", .int 5)] == some { branch := none, payload := some (.int 0) } := by
  native_decide

/-- Thunk leaves resolve through the asserted oracle — the kernel
re-decides the dispatch around the asserted result, never the leaf. -/
def gThunk : Graph :=
  [ ("tick", .thunk)
  , ("main", .subflow {
      head := ("tick", [("n", .lit (.int 5))])
      arms := [ { branch := "go", bind := some "i",
                  node := some (.produce (.var "i")) } ] }) ]

def oThunk : Oracle := [ (("tick", [("n", .int 5)]), { branch := some "go", payload := some (.int 5) }) ]

theorem eval_thunk :
    eval gThunk oThunk 16 "main" [] == some { branch := none, payload := some (.int 5) } := by
  native_decide

/-- A thunk call with no asserted leaf refuses — the kernel does not
invent native results. -/
theorem eval_thunk_unasserted : eval gThunk [] 16 "main" [] == none := by
  native_decide

/-- A binding arm on a payload-less result refuses — `| go i` cannot
bind what was never delivered. -/
def gVoidBind : Graph :=
  [ ("tick", .thunk)
  , ("main", .subflow {
      head := ("tick", [])
      arms := [ { branch := "go", bind := some "i",
                  node := some (.produce (.var "i")) } ] }) ]

def oVoid : Oracle := [ (("tick", []), { branch := some "go", payload := none }) ]

theorem eval_bind_no_payload : eval gVoidBind oVoid 16 "main" [] == none := by
  native_decide

/-- A catchall arm hit during bare dispatch refuses — matching the
walker's loud wall. -/
def gCatchBare : Graph :=
  [ ("one", .bare (.lit (.int 1)))
  , ("main", .subflow {
      head := ("one", [])
      arms := [ { catchall := true, node := some (.produce (.lit (.int 9))) } ] }) ]

theorem eval_catchall_bare : eval gCatchBare [] 16 "main" [] == none := by
  native_decide

/-- A VOID call plus arms is a refusal — `dispatchArms`' first act on a
tagless result is `payload == null → fail`, before any arm scans.
`inner`'s chain ends terminal, so the flow result is void; `main`'s
arm can never see it. This pins the refusal the audit caught the
first kernel missing. -/
def gVoidArms : Graph :=
  [ ("mk", .bare (.lit (.int 0)))
  , ("inner", .subflow {
      head := ("mk", [])
      arms := [ { branch := "x", node := some .terminal } ] })
  , ("main", .subflow {
      head := ("inner", [])
      arms := [ { branch := "y", node := some (.produce (.lit (.int 9))) } ] }) ]

theorem eval_void_arms : eval gVoidArms [] 32 "main" [] == none := by
  native_decide

/-- The same chain without a dispatching caller: a terminal arm ends
the chain, `.done` surfaces as a void result. -/
theorem eval_terminal_void :
    eval gVoidArms [] 16 "inner" [] == some { branch := none, payload := none } := by
  native_decide

/-- Nested invocation dispatch: an arm's `|> call` result is dispatched
by the arm's own nested arms (`conts`), under the arm's bound env —
`dispatchArms(arm.continuations, result, env)`. The second `step` call
tags `go`, the nested `| go` arm binds `t` and produces it. -/
def gNested : Graph :=
  [ ("step", .thunk)
  , ("main", .subflow {
      head := ("step", [("n", .lit (.int 1))])
      arms := [ { branch := "start", bind := some "s",
                  node := some (.invoke "step" [("n", .var "s")]),
                  conts := [ { branch := "go", bind := some "t",
                               node := some (.produce (.var "t")) } ] } ] }) ]

def oNested : Oracle :=
  [ (("step", [("n", .int 1)]), { branch := some "start", payload := some (.int 41) })
  , (("step", [("n", .int 41)]), { branch := some "go", payload := some (.int 7) }) ]

theorem eval_nested :
    eval gNested oNested 32 "main" [] == some { branch := none, payload := some (.int 7) } := by
  native_decide

/-- Callee envs are fresh — `walkFlow` binds only the call's own args.
`leak` looks up `y` under an empty env even though the caller bound a
`y` in its arm scope: caller bindings never leak into a call. -/
def gFresh : Graph :=
  [ ("leak", .bare (.var "y"))
  , ("mk", .bare (.lit (.int 0)))
  , ("main", .subflow {
      head := ("mk", [])
      arms := [ { branch := "x", bind := some "y",
                  node := some (.invoke "leak" []) } ] }) ]

theorem eval_fresh_env : eval gFresh [] 32 "main" [] == none := by
  native_decide

/-- Named args bind by name — the positive half of env isolation. -/
def gNamed : Graph := [ ("id", .bare (.var "x")) ]

theorem eval_named_arg :
    eval gNamed [] 8 "id" [("x", .int 9)] == some { branch := none, payload := some (.int 9) } := by
  native_decide

/-- Fuel exhausts rather than diverging: the countdown needs a step
count proportional to its iterations. -/
theorem eval_fuel_short :
    run gCount [] 6 (.invoke "count" [("n", .int 5)]) == none := by native_decide

/-- `and` short-circuits: `false and <refusing>` is `false`, not a
refusal — `expectBool` on the right is never reached. -/
theorem eval_and_short :
    evalE [] (.bin .and (.lit (.bool false)) (.bin .div (.lit (.int 1)) (.lit (.int 0))))
      == some (.bool false) := by native_decide

/-- `or` short-circuits the other way: `true or <refusing>` is `true`. -/
theorem eval_or_short :
    evalE [] (.bin .or (.lit (.bool true)) (.bin .div (.lit (.int 1)) (.lit (.int 0))))
      == some (.bool true) := by native_decide

/-- A decided left still forces the right's bool-ness: `true and 5`
is a TypeMismatch, not `true`. -/
theorem eval_and_typeerr :
    evalE [] (.bin .and (.lit (.bool true)) (.lit (.int 5))) == none := by native_decide

/-- Truncating division — the C-parity `@divTrunc`, not Lean's floored
`Int.ediv`: `-7 / 2` is `-3` here, `-4` floored. -/
theorem eval_div_trunc_neg :
    evalE [] (.bin .div (.lit (.int (-7))) (.lit (.int 2))) == some (.int (-3)) := by
  native_decide

/-- C-style `%` is `@rem` — sign follows the dividend: `-7 % 2 = -1`. -/
theorem eval_rem_neg :
    evalE [] (.bin .mod (.lit (.int (-7))) (.lit (.int 2))) == some (.int (-1)) := by
  native_decide

/-- `@mod` floors — the third flavor the builtins carry: `-7 mod 2 = 1`,
the opposite sign from `@rem`. -/
theorem eval_mod_floors :
    evalE [] (.builtin "mod" [.lit (.int (-7)), .lit (.int 2)]) == some (.int 1) := by
  native_decide

/-- `@divTrunc` through the builtin path agrees with `/`. -/
theorem eval_builtin_divTrunc :
    evalE [] (.builtin "divTrunc" [.lit (.int (-7)), .lit (.int 2)]) == some (.int (-3)) := by
  native_decide

/-- `@as`'s type argument is a NAME, never evaluated — `@as(i32, 5)`
yields 5 even though `i32` binds nothing in the env. Pins the
lazy-argument boundary the audit caught: an eager args-list would
refuse here. -/
theorem eval_as_lazy_type :
    evalE [] (.builtin "as" [.var "i32", .lit (.int 5)]) == some (.int 5) := by
  native_decide

/-- Unknown builtins refuse; arity mismatches refuse. -/
theorem eval_builtin_unknown :
    evalE [] (.builtin "floatSqrt" [.lit (.int 4)]) == none := by native_decide

theorem eval_builtin_arity :
    evalE [] (.builtin "divTrunc" [.lit (.int 1)]) == none := by native_decide

/-- `>`/`>=` — the comparison surface the first kernel missed. -/
theorem eval_gt :
    evalE [] (.bin .gt (.lit (.int 3)) (.lit (.int 3))) == some (.bool false) := by
  native_decide

theorem eval_ge :
    evalE [] (.bin .ge (.lit (.int 3)) (.lit (.int 3))) == some (.bool true) := by
  native_decide

/-- `++` is a distinct op — `+` on strings refuses, `++` joins. -/
theorem eval_str_concat :
    evalE [] (.bin .concat (.lit (.str "a")) (.lit (.str "b"))) == some (.str "ab") := by
  native_decide

theorem eval_str_add_refuses :
    evalE [] (.bin .add (.lit (.str "a")) (.lit (.str "b"))) == none := by native_decide

/-- The conditional node — lazy branches like the walker's
`ExprNode.conditional`: the untaken side is never evaluated, so a
refusing branch doesn't poison the result. -/
theorem eval_cond_lazy :
    evalE [] (.cond (.lit (.bool true)) (.lit (.int 1))
                    (.bin .div (.lit (.int 1)) (.lit (.int 0))))
      == some (.int 1) := by native_decide

/-- A non-bool condition is a TypeMismatch. -/
theorem eval_cond_typeerr :
    evalE [] (.cond (.lit (.int 1)) (.lit (.int 1)) (.lit (.int 2))) == none := by
  native_decide

/-- Any float promotes both operands — `1 + 0.5 = 1.5` through
`asFloat`. -/
theorem eval_float_promote :
    evalE [] (.bin .add (.lit (.int 1)) (.lit (.float 0.5))) == some (.float 1.5) := by
  native_decide

/-- Float division has no zero check — IEEE `inf`, like the walker. -/
theorem eval_float_div_zero :
    evalE [] (.bin .div (.lit (.float 1.0)) (.lit (.float 0.0))) == some (.float (1.0 / 0.0)) := by
  native_decide

/-- Unary neg works on both numeric flavors; `not` needs a bool. -/
theorem eval_un_neg_float :
    evalE [] (.un .neg (.lit (.float 2.5))) == some (.float (-2.5)) := by native_decide

theorem eval_un_not_typeerr :
    evalE [] (.un .not (.lit (.int 1))) == none := by native_decide

/-- Array indexing — arrays enter through thunk results, but the
kernel still re-decides index expressions over them. -/
theorem eval_index_arr :
    evalE [] (.index (.lit (.arr [.int 10, .int 20, .int 30])) (.lit (.int 1)))
      == some (.int 20) := by native_decide

/-- Out-of-range and negative indices refuse; non-array refuses. -/
theorem eval_index_oob :
    evalE [] (.index (.lit (.arr [.int 10])) (.lit (.int 5))) == none := by native_decide

theorem eval_index_neg :
    evalE [] (.index (.lit (.arr [.int 10])) (.lit (.int (-1)))) == none := by
  native_decide

/-- Cell field access — `put`-overwrite parity: last binding wins. -/
theorem eval_field_cell :
    evalE [] (.field (.lit (.cell [("x", .int 1), ("x", .int 2), ("y", .int 3)])) "x")
      == some (.int 2) := by native_decide

/-- A missing field refuses; field access on a non-cell refuses. -/
theorem eval_field_missing :
    evalE [] (.field (.lit (.cell [("x", .int 1)])) "z") == none := by native_decide

theorem eval_field_typeerr :
    evalE [] (.field (.lit (.int 5)) "x") == none := by native_decide

/-! ## Metatheorems -/

/-- `asResult` inversion: it yields `some r` only from `some (.result r)`. -/
theorem asResult_some {o : Option Outcome} {r : Result}
    (h : asResult o = some r) : o = some (.result r) := by
  cases o with
  | none => simp [asResult] at h
  | some out => cases out <;> simp_all [asResult]

/-- Fuel monotonicity: once a run decides, more fuel cannot change the
result. This is why fuel-bounded evaluation is safe — `none` at a
given fuel means "undecided or refusing", never "computed differently".
Single `run` function ⇒ single induction; every recursive step is at
strictly smaller fuel, so the IH discharges every tail call. -/
theorem run_mono (g : Graph) (o : Oracle) :
    ∀ (fuel : Nat) (c : Call) (x : Outcome),
    run g o fuel c = some x →
    run g o (fuel + 1) c = some x := by
  intro fuel
  induction fuel with
  | zero =>
    intro c x h
    rw [run] at h
    exact nomatch h
  | succ f ih =>
    intro c x h
    cases c with
    | invoke name args =>
      rw [run] at h ⊢
      cases hlk : g.lookup name with
      | none => rw [hlk] at h; exact nomatch h
      | some cb =>
        rw [hlk] at h
        cases cb with
        | thunk => exact h
        | bare e => exact h
        | subflow fl => exact ih _ _ h
    | flow fl callArgs =>
      rw [run] at h ⊢
      cases hargs : evalArgs (argEnv callArgs) fl.head.2 with
      | none => rw [hargs] at h; exact nomatch h
      | some hv => rw [hargs] at h; exact ih _ _ h
    | loop fl env hargs =>
      rw [run] at h ⊢
      cases hr : run g o f (.invoke fl.head.1 hargs) with
      | none => rw [hr] at h; exact nomatch h
      | some o1 =>
        rw [hr] at h
        cases o1 with
        | result r =>
          rw [ih _ _ hr]
          dsimp only at h ⊢
          cases hE : fl.arms.isEmpty with
          | true => rw [hE] at h; exact h
          | false =>
            rw [hE] at h
            cases hbr : r.branch with
            | some b =>
              rw [hbr] at h
              dsimp only at h ⊢
              cases hD : run g o f (.dispatchTag env fl.arms b r) with
              | none => rw [hD] at h; exact nomatch h
              | some o2 =>
                rw [hD] at h
                rw [ih _ _ hD]
                cases o2 with
                | result rr => exact h
                | done => exact h
                | jump lbl jargs =>
                  dsimp only at h ⊢
                  cases hl : (fl.preLabel == some lbl) with
                  | true => rw [hl] at h; exact ih _ _ h
                  | false => rw [hl] at h; exact nomatch h
                | skip => exact nomatch h
            | none =>
              rw [hbr] at h
              dsimp only at h ⊢
              cases hD : run g o f (.dispatchBare env fl.arms r) with
              | none => rw [hD] at h; exact nomatch h
              | some o2 =>
                rw [hD] at h
                rw [ih _ _ hD]
                cases o2 with
                | result rr => exact h
                | done => exact h
                | jump lbl jargs =>
                  dsimp only at h ⊢
                  cases hl : (fl.preLabel == some lbl) with
                  | true => rw [hl] at h; exact ih _ _ h
                  | false => rw [hl] at h; exact nomatch h
                | skip => exact nomatch h
        | done => exact nomatch h
        | jump _ _ => exact nomatch h
        | skip => exact nomatch h
    | dispatchTag env arms b r =>
      cases arms with
      | nil => rw [run] at h; exact nomatch h
      | cons a rest =>
        rw [run] at h ⊢
        cases hE : (a.branch != b) with
        | true => rw [hE] at h; exact ih _ _ h
        | false =>
          rw [hE] at h
          cases hD : run g o f (.armTry env a r) with
          | none => rw [hD] at h; exact nomatch h
          | some o1 =>
            rw [hD] at h
            rw [ih _ _ hD]
            cases o1 with
            | skip => exact ih _ _ h
            | _ => exact h
    | dispatchBare env arms r =>
      cases arms with
      | nil =>
        rw [run] at h
        cases hp : r.payload with
        | none => rw [hp] at h; exact nomatch h
        | some v => rw [hp] at h; exact nomatch h
      | cons a rest =>
        rw [run] at h ⊢
        cases hp : r.payload with
        | none => rw [hp] at h; exact nomatch h
        | some v =>
          rw [hp] at h
          dsimp only at h ⊢
          cases hE : (a.catchall || a.branch == "") with
          | true => rw [hE] at h; exact nomatch h
          | false =>
            rw [hE] at h
            cases hD : run g o f (.armTry env a r) with
            | none => rw [hD] at h; exact nomatch h
            | some o1 =>
              rw [hD] at h
              rw [ih _ _ hD]
              cases o1 with
              | skip => exact ih _ _ h
              | _ => exact h
    | armTry env a r =>
      rw [run] at h ⊢
      cases hb : bindArmEnv a env r with
      | none => rw [hb] at h; exact nomatch h
      | some env' =>
        rw [hb] at h
        dsimp only at h ⊢
        cases hg : evalGuard env' a with
        | none => rw [hg] at h; exact nomatch h
        | some p =>
          rw [hg] at h
          dsimp only at h ⊢
          cases p with
          | true => exact ih _ _ h
          | false => exact h
    | armWalk env a r =>
      rw [run] at h ⊢
      cases hn : a.node with
      | none => rw [hn] at h; exact h
      | some nd =>
        rw [hn] at h
        cases nd with
        | terminal => exact h
        | jump lbl aexprs => exact h
        | invoke name aexprs =>
          dsimp only at h ⊢
          cases ha : evalArgs env aexprs with
          | none => rw [ha] at h; exact nomatch h
          | some hargs =>
            rw [ha] at h
            dsimp only at h ⊢
            cases hr : run g o f (.invoke name hargs) with
            | none => rw [hr] at h; exact nomatch h
            | some o1 =>
              rw [hr] at h
              cases o1 with
              | result r =>
                rw [ih _ _ hr]
                dsimp only at h ⊢
                cases hE : a.conts.isEmpty with
                | true => rw [hE] at h; exact h
                | false =>
                  rw [hE] at h
                  cases hbr : r.branch with
                  | some b => rw [hbr] at h; exact ih _ _ h
                  | none => rw [hbr] at h; exact ih _ _ h
              | done => exact nomatch h
              | jump _ _ => exact nomatch h
              | skip => exact nomatch h
        | produce e => exact h
        | retCtor b e => exact h

end Koru.FlowKernel
