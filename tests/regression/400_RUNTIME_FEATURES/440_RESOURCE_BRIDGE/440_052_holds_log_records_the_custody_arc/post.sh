#!/bin/bash
# Pins the holds.log FORMAT — the custody ledger a successor session
# reads. Field names and ordering are the contract; the minted hex and
# the millisecond timestamps are the parts a pin must not spell.
#
# holds.log is append-only across program runs into the same world, so
# the pin is written against accumulation: every line must be one of
# the four custody shapes, opens pair with closes, and the trailing
# session block shows mint and release naming the same handle.
set -u
cd "$(dirname "$0")"
fail() { echo "FAIL: $1"; rm -rf world; exit 1; }

log=world/holds.log
[ -f "$log" ] || fail "world/holds.log was not written"

# Every line is one of the four shapes — no field drift anywhere in
# the file, however many runs have appended to it.
bad=$(grep -vx 'session-open	t=[0-9]*	session=w1\|session-closed	t=[0-9]*	session=w1\|mint	t=[0-9]*	session=w1	handle=h:Res:[0-9a-f]\{6\}	verb=mint	type=Res	subject=.*\|release	t=[0-9]*	session=w1	handle=h:Res:[0-9a-f]\{6\}	by=release' "$log" | head -1 || true)
[ -z "$bad" ] || fail "non-custody or malformed line: $bad"

opens=$(grep -c 'session-open' "$log")
closes=$(grep -c 'session-closed' "$log")
[ "$opens" -eq "$closes" ] || fail "unpaired session markers: $opens opens, $closes closes"

# The trailing block is this run's session: open, mint, release,
# closed — and release names the token mint minted.
block=$(tail -4 "$log")
echo "$block" | sed -n '1p' | grep -qx 'session-open	t=[0-9]*	session=w1' \
    || fail "block head is not session-open: $(echo "$block" | sed -n '1p')"
echo "$block" | sed -n '4p' | grep -qx 'session-closed	t=[0-9]*	session=w1' \
    || fail "block tail is not session-closed: $(echo "$block" | sed -n '4p')"

minted=$(echo "$block" | sed -n '2p' | grep -o 'handle=[^	]*' | cut -d= -f2)
freed=$(echo "$block" | sed -n '3p' | grep -o 'handle=[^	]*' | cut -d= -f2)
[ -n "$minted" ] || fail "block mint line carries no handle"
[ "$minted" = "$freed" ] || fail "release handle '$freed' != minted '$minted'"

# The worldless session (w2) writes nothing anywhere the test can see.
[ ! -e holds.log ] || fail "worldless session wrote a holds.log into the test dir"

rm -rf world
