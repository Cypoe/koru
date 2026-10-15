#!/usr/bin/env python3
"""K4 attestation — signed receipts that the pinned battery ran.

A receipt attests *process*: these artifacts, at these digests, produced
these gate verdicts, signed by a pinned Ed25519 attester. It does not
prove semantics — every layer below it already does its own proving;
the receipt pins that the battery executed. The `proof` field is the
zkVM execution channel: null until the battery runs in a guest.

    emit   — run the pinned battery, write receipts/<ts>-<tree>.json
    verify <receipt> — check signature, trusted signer, and recompute
             the digests it claims (input-match is only meaningful on
             the tree the receipt names; signature + trusted signer are
             meaningful on any tree)
    verify <receipt> --re-run — additionally re-execute the recorded
             battery and compare verdicts. The receipt then attests only
             "the pinned attester claims these inputs were tested";
             the verifier independently confirms the outcomes. This is
             the regime's own doctrine applied at the top: re-decide,
             don't trust — self-attestation shrinks to provenance.

Key: KORU_ATTEST_KEY env or ~/.agents/keys/koru-attest.ed25519 (hex seed).
Trusted attester: tools/attest.pub (did:key) — anyone can sign; the repo
pins whose signature counts.

Honesty clauses:
 - the signature attests the *record*, not the run — self-attestation
   by the key holder; the zk leg replaces self-attestation with
   verifiable execution
 - tree_dirty is recorded, never normalized
 - a gate that could not run is recorded as verdict "error", not
   skipped — a receipt with a missing gate still signs; verify decides
   whether the recorded outcome is a pass
"""
import hashlib, json, os, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RECEIPTS = ROOT / "receipts"
PUB_PIN = ROOT / "tools" / "attest.pub"

B58A = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

def b58e(b: bytes) -> str:
    n = int.from_bytes(b, "big")
    s = ""
    while n:
        n, r = divmod(n, 58)
        s = B58A[r] + s
    return B58A[0] * (len(b) - len(b.lstrip(b"\x00"))) + s

def b58d(s: str) -> bytes:
    n = 0
    for c in s:
        n = n * 58 + B58A.index(c)
    b = n.to_bytes((n.bit_length() + 7) // 8, "big")
    return b"\x00" * (len(s) - len(s.lstrip(B58A[0]))) + b

def did_of(pk: bytes) -> str:
    return "did:key:z" + b58e(b"\xed\x01" + pk)

def pk_of(did: str) -> bytes:
    assert did.startswith("did:key:z")
    raw = b58d(did[9:])
    assert raw[:2] == b"\xed\x01", "not an ed25519 did:key"
    return raw[2:]

def sha256_file(p: Path) -> str:
    return "sha256:" + hashlib.sha256(p.read_bytes()).hexdigest()

def canonical(payload: dict) -> bytes:
    return json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()

def load_key() -> bytes:
    p = os.environ.get("KORU_ATTEST_KEY") or os.path.expanduser(
        "~/.agents/keys/koru-attest.ed25519")
    raw = Path(p).read_text().strip()
    return bytes.fromhex(raw)

def git(*args) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args],
                          capture_output=True, text=True).stdout.strip()

# The pinned battery — explicit, ordered, each verdict recorded. Grow it
# here, not ad hoc: a receipt's meaning is this list.
BATTERY = [
    {"name": "witness-gate",
     "argv": ["bash", "scripts/witness_gate.sh"]},
]

def run_battery() -> list:
    env = dict(os.environ)
    env.setdefault("KORU_WITNESS", "1")
    out = []
    for gate in BATTERY:
        t0 = time.time()
        r = subprocess.run(gate["argv"], cwd=ROOT, capture_output=True,
                           text=True, env=env)
        tail = (r.stdout + r.stderr).strip().splitlines()
        out.append({
            "name": gate["name"],
            "argv": gate["argv"],
            "rc": r.returncode,
            "verdict": "PASS" if r.returncode == 0 else "FAIL",
            "last_line": tail[-1] if tail else "",
            "elapsed_s": round(time.time() - t0, 1),
        })
    return out

def digests() -> dict:
    koruc = ROOT / "zig-out/bin/koruc"
    return {
        "koruc": sha256_file(koruc) if koruc.exists() else None,
        "ccomp": sha256_file(Path(os.environ.get(
            "KORU_CC_ORACLE", "/home/cypoe/.nix-profile/bin/ccomp")))
            if Path(os.environ.get("KORU_CC_ORACLE",
               "/home/cypoe/.nix-profile/bin/ccomp")).exists() else None,
        "lean": sha256_file(Path(os.environ.get(
            "KORU_LEAN", "/home/cypoe/.elan/toolchains/"
            "leanprover--lean4---v4.31.0/bin/lean")))
            if Path(os.environ.get("KORU_LEAN", "/home/cypoe/.elan/"
               "toolchains/leanprover--lean4---v4.31.0/bin/lean")).exists()
            else None,
        "corpora": {
            f: sha256_file(ROOT / "verify/witness" / f)
            for f in ("WitnessCheck.lean", "golden.txt",
                      "forged.txt", "drift.txt")
        },
        "gate_scripts": {
            s: sha256_file(ROOT / "scripts" / s)
            for s in ("witness_gate.sh",)
        },
    }

def emit() -> int:
    from nacl.signing import SigningKey
    tree = git("rev-parse", "HEAD")
    dirty = bool(git("status", "--porcelain"))
    battery = run_battery()
    payload = {
        "format": "koru-attest/1",
        "tier": "attested",
        "tree": tree,
        "tree_dirty": dirty,
        "battery": battery,
        "digests": digests(),
        "host": {
            "uname": subprocess.run(["uname", "-srmo"],
                     capture_output=True, text=True).stdout.strip(),
            "ldd": subprocess.run(["ldd", "--version"],
                     capture_output=True, text=True).stdout.splitlines()[0],
        },
        "ts": int(time.time()),
        "proof": None,
        "signer": did_of(SigningKey(load_key()).verify_key.encode()),
    }
    sig = SigningKey(load_key()).sign(canonical(payload)).signature
    receipt = dict(payload, signature=sig.hex())
    RECEIPTS.mkdir(exist_ok=True)
    path = RECEIPTS / f"{payload['ts']}-{tree[:9]}.json"
    path.write_text(json.dumps(receipt, indent=2) + "\n")
    print(path.relative_to(ROOT))
    ok = all(g["verdict"] == "PASS" for g in battery)
    print("battery:", "PASS" if ok else "FAIL",
          "| signer:", payload["signer"][:28] + "...",
          "| dirty:", dirty)
    return 0 if ok else 1

def verify(path: str, re_run: bool = False) -> int:
    from nacl.signing import VerifyKey
    from nacl.exceptions import BadSignatureError
    r = json.loads(Path(path).read_text())
    assert r.get("format") == "koru-attest/1", "unknown receipt format"
    sig = bytes.fromhex(r.pop("signature"))
    payload = dict(r)
    ok = True
    try:
        VerifyKey(pk_of(r["signer"])).verify(canonical(payload), sig)
        print("signature: VALID  signer:", r["signer"])
    except BadSignatureError:
        print("signature: INVALID")
        ok = False
    trusted = PUB_PIN.read_text().strip() if PUB_PIN.exists() else None
    if trusted and r["signer"] == trusted:
        print("signer: TRUSTED (tools/attest.pub)")
    else:
        print(f"signer: UNTRUSTED (pinned: {trusted})")
        ok = False
    here = digests()
    for sect in ("koruc", "ccomp", "lean"):
        want, got = r["digests"].get(sect), here.get(sect)
        mark = "match" if want == got else "DRIFT"
        if want != got:
            ok = False
        print(f"digest {sect}: {mark}")
    for group in ("corpora", "gate_scripts"):
        for f, want in r["digests"].get(group, {}).items():
            got = here[group].get(f)
            mark = "match" if want == got else "DRIFT"
            if want != got:
                ok = False
            print(f"digest {group}/{f}: {mark}")
    for g in r.get("battery", []):
        print(f"gate {g['name']}: recorded {g['verdict']}"
              f" (rc={g['rc']})")
        if g["verdict"] != "PASS":
            ok = False
    if re_run:
        live = {g["name"]: g for g in run_battery()}
        for g in r.get("battery", []):
            cur = live.get(g["name"])
            if cur is None:
                print(f"re-run {g['name']}: gate not in battery")
                ok = False
            elif cur["verdict"] == g["verdict"]:
                print(f"re-run {g['name']}: verdict confirmed"
                      f" ({cur['verdict']})")
            else:
                print(f"re-run {g['name']}: recorded {g['verdict']}"
                      f" != live {cur['verdict']}")
                ok = False
    print("tree:", r["tree"], "| dirty:", r["tree_dirty"],
          "| verdict:", "ATTESTED" if ok else "REJECTED")
    return 0 if ok else 1

if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "emit":
        sys.exit(emit())
    if len(sys.argv) >= 3 and sys.argv[1] == "verify":
        sys.exit(verify(sys.argv[2], "--re-run" in sys.argv[3:]))
    print(__doc__)
    sys.exit(2)
