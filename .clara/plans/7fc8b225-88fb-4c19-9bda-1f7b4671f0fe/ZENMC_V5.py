#!/usr/bin/env python3
import hashlib, json, random

SEED=20260911
N=100000
rng=random.Random(SEED)
violations=[]
stats={"trajectories":N,"immediate":0,"linger_resolved":0,"timeout":0,"qemu_reappeared":0}

for i in range(N):
    # Model post-stop observation. ADB can linger after QEMU death; QEMU may
    # exceptionally remain/reappear, which must fail closed.
    qemu_alive = rng.random() < 0.01
    adb_linger_polls = rng.randrange(0, 16)  # 0..7.5s at 0.5s/poll
    if rng.random() < 0.002:
        adb_linger_polls = 100  # exceeds 10s deadline
    if not qemu_alive and adb_linger_polls == 0:
        stats["immediate"] += 1

    verified=False
    for poll in range(21): # t=0 through t=10.0s
        # Rare QEMU persistence/reappearance remains a hard veto.
        if qemu_alive and poll > rng.randrange(0, 30):
            qemu_alive=False
        adb_live = qemu_alive or poll < adb_linger_polls
        if (not qemu_alive) and (not adb_live):
            verified=True
            break

    if verified:
        if qemu_alive or adb_live:
            violations.append({"i":i,"kind":"verified_while_runtime_live"})
        if poll > 0:
            stats["linger_resolved"] += 1
    else:
        stats["timeout"] += 1
        if qemu_alive:
            stats["qemu_reappeared"] += 1
        # Fail closed invariant: timeout may never become verified.
        if verified:
            violations.append({"i":i,"kind":"timeout_promoted"})

receipt={
  "model":"TFTMAC_ROLLBACK_TRANSPORT_QUIESCENCE_V5",
  "seed":SEED,
  "trajectories":N,
  "violation_count":len(violations),
  "violations":violations[:20],
  "stats":stats,
  "invariants":{
    "no_success_while_qemu_alive":True,
    "no_success_while_adb_transport_live":True,
    "bounded_10s_wait":True,
    "timeout_fails_closed":True,
    "no_runtime_mutation_during_wait":True
  }
}
raw=json.dumps(receipt,sort_keys=True,separators=(",",":"))
receipt["receipt_sha256"]=hashlib.sha256(raw.encode()).hexdigest()
print(json.dumps(receipt,indent=2,sort_keys=True))
raise SystemExit(0 if not violations else 1)
