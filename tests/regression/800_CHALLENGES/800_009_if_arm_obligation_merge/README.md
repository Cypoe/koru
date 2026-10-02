# 800_009 — if_arm_obligation_merge

**Pitch:** an obligation consumed in *both* arms of an `if` is still
'released-live' at the merge — the `|>` continuation after the if is
blamed for an obligation that no longer exists.

**Tier:** frontier pin (MUST_ERROR).

## What it pins

`p` is minted `<held!>`, then either arm of the `if` runs it through a
full consume chain ending in `file-dispatch` (`<!delivered>`). Both
arms discharge the same binding — the natural shape for a conditional
dispatch. The checker refuses at the `|>` continuation after the if:

```
error[KORU030]: Resource 'p' obligation <held!> was not discharged.
    |> std/store:stored { board.n: board.n + 1 }
```

**Expected:** the merge tracks that both arms consumed `p`; nothing is
left to discharge, the program compiles and runs.
**Actual:** KORU030 — `p` is treated as still holding `<held!>` past the
if, and the auto-discharger finds no void acceptor for it.

## Narrowed

- Not union-consume: the repro uses single-state `<!held>` consumers
  (`sign`, `stamp-express`) in both arms.
- Not if-consumption generally: the same program with the `if`
  *terminal* (each arm ends in a print) compiles and runs.
- The trigger is the `|>` continuation after the if — consumption
  inside arms does not propagate to the merge.

## Surfaced by

`800_008_relay` — its `send-all` originally counted sends on a `|>`
step after the if that routed each pouch; both arms discharged `p`,
KORU030 fired anyway. The shipped row counts inside each arm.
