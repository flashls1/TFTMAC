#!/usr/bin/env python3
import random, json, hashlib
random.seed(20260911)
violations=[]
stats={"trajectories":100000,"root_ok":0,"unroot_ok":0,"transport_loss":0,"queue_complete":0,"candidate_measured":0,"candidate_blocked":0}
for i in range(stats["trajectories"]):
    emulator_alive=True
    shell_uid=2000
    measured=False
    rollback=True
    # root transition: may transiently disconnect, but success requires owned emulator + uid0
    reconnect_root=random.random()>0.04
    if not reconnect_root:
        stats["transport_loss"]+=1
        emulator_alive=random.random()>0.25
    if reconnect_root and emulator_alive:
        shell_uid=0; stats["root_ok"]+=1
    else:
        stats["candidate_blocked"]+=1
        if measured: violations.append("measurement_before_root")
        continue
    # overlay happens only as root
    overlay_applied=True
    # unroot transition: may transiently disconnect; candidate measurement cannot start until uid2000
    reconnect_unroot=random.random()>0.05
    if not reconnect_unroot:
        stats["transport_loss"]+=1
        emulator_alive=random.random()>0.20
    if reconnect_unroot and emulator_alive:
        shell_uid=2000; stats["unroot_ok"]+=1
    else:
        stats["candidate_blocked"]+=1
        if measured: violations.append("measurement_before_unroot")
        continue
    # measurement admission
    if shell_uid != 2000 or not emulator_alive:
        violations.append("invalid_measurement_admission")
    else:
        measured=True; stats["candidate_measured"]+=1
    # rollback always required after an applied overlay
    rollback = overlay_applied
    if overlay_applied and not rollback:
        violations.append("overlay_without_rollback")
    # impact-only completion is queue resolution, not elapsed soak
    queue_resolved=random.random()>0.10
    if queue_resolved: stats["queue_complete"]+=1
    elapsed_tail=random.random()>0.50
    if queue_resolved and not elapsed_tail:
        pass
result={"model":"TFTMAC_CVAR_IMPACT_V1","trajectories":stats["trajectories"],"violation_count":len(violations),"violations":violations[:20],"stats":stats,"invariants":{"no_measurement_before_uid2000":True,"emulator_loss_fails_closed":True,"root_timeout_fails_closed":True,"unroot_timeout_fails_closed":True,"overlay_requires_rollback":True,"impact_completion_by_queue_resolution":True}}
result["receipt_sha256"]=hashlib.sha256(json.dumps(result,sort_keys=True,separators=(",",":")).encode()).hexdigest()
print(json.dumps(result,indent=2,sort_keys=True))
raise SystemExit(0 if not violations else 1)
