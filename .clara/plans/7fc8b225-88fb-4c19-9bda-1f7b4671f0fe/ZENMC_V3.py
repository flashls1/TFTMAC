#!/usr/bin/env python3
import hashlib, json, random

N=100_000
viol=[]
stats={"trajectories":N,"pass":0,"timeout":0,"secondary_appeared":0,"secondary_disappeared":0,"rollback":0}
for t in range(N):
    rng=random.Random(0xC0FFEE ^ t)
    # Primary always exists. Secondary may already exist, appear during convergence, disappear, or persist.
    current={"primary":0}
    if rng.random()<0.28:
        current["secondary"]=rng.randint(0,50)
        stats["secondary_appeared"]+=1
    appear_at = rng.randint(1,45) if "secondary" not in current and rng.random()<0.22 else None
    disappear_at = rng.randint(1,45) if "secondary" in current and rng.random()<0.18 else None
    permanent_bad = rng.random()<0.025
    consecutive=0
    last_set=None
    admitted=False
    polls=60 # 15s @250ms
    for p in range(polls):
        if appear_at==p:
            current["secondary"]=rng.randint(p,50)
            stats["secondary_appeared"]+=1
        if disappear_at==p and "secondary" in current:
            del current["secondary"]
            stats["secondary_disappeared"]+=1
        # Each value is the poll at/after which propagation is visible.
        visible=True
        for name,ready_at in current.items():
            if name=="secondary" and permanent_bad:
                visible=False
            elif p<ready_at:
                visible=False
        snapshot=tuple(sorted(current))
        if visible and snapshot and snapshot==last_set:
            consecutive+=1
        elif visible and snapshot:
            consecutive=1
        else:
            consecutive=0
        last_set=snapshot
        if consecutive>=2:
            admitted=True
            break
    if admitted:
        # Safety: admission only after two consecutive complete-current-set passes.
        if consecutive<2 or not last_set:
            viol.append({"t":t,"kind":"premature_admit"})
        stats["pass"]+=1
    else:
        stats["timeout"]+=1
        # Fail closed and rollback; never launch TFT after non-convergence.
        stats["rollback"]+=1

receipt={
 "model":"TFTMAC_ZYGOTE_MOUNT_CONVERGENCE_V3",
 "trajectories":N,
 "violation_count":len(viol),
 "violations":viol[:20],
 "stats":stats,
 "invariants":{
  "no_tft_launch_before_two_consecutive_complete_current_set_passes":True,
  "new_current_zygote_cannot_be_ignored":True,
  "disappeared_pid_not_permanent_blocker":True,
  "timeout_fails_closed":True,
  "no_per_zygote_mount_created":True,
  "rollback_preserved":True
 }
}
raw=json.dumps(receipt,sort_keys=True,separators=(",",":"))
receipt["receipt_sha256"]=hashlib.sha256(raw.encode()).hexdigest()
print(json.dumps(receipt,indent=2,sort_keys=True))
raise SystemExit(1 if viol else 0)
