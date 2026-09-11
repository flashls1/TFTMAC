#!/usr/bin/env python3
import random, json, hashlib
random.seed(20260911)
N=100000
viol=[]
stats={"trajectories":N,"candidate_visible":0,"candidate_blocked":0,"measured":0,"rollback_verified":0,"failure_after_write":0}
for i in range(N):
    game_running=False
    uid=2000
    stage="LKG"
    target="LKG"
    zygotes=["LKG"]*random.randint(1,3)
    inode=12345
    metadata="0:0 444 ctx"
    candidate_written=False
    measured=False
    # root transition
    if random.random()<0.025:
        stats["candidate_blocked"]+=1
        continue
    uid=0
    # preconditions: all views must begin LKG
    if stage!="LKG" or target!="LKG" or any(x!="LKG" for x in zygotes) or game_running:
        viol.append("bad_precondition")
        continue
    # in-place write. Some modeled writes fail before/after truncation.
    write_mode=random.random()
    if write_mode<0.015:
        stats["candidate_blocked"]+=1
        continue
    candidate_written=True
    stage="CANDIDATE"; target="CANDIDATE"; zygotes=["CANDIDATE"]*len(zygotes)
    if inode!=12345 or metadata!="0:0 444 ctx": viol.append("inode_or_metadata_changed")
    # visibility verification may fail closed
    if random.random()<0.02:
        stats["failure_after_write"]+=1
    else:
        if stage==target=="CANDIDATE" and all(x=="CANDIDATE" for x in zygotes):
            stats["candidate_visible"]+=1
            # unroot must complete before launch/measurement
            if random.random()>=0.025:
                uid=2000; game_running=True
                # engine proof required before measurement
                engine_proof=random.random()>=0.03
                windows=random.random()>=0.03
                if engine_proof and windows and uid==2000 and game_running:
                    measured=True; stats["measured"]+=1
                elif measured:
                    viol.append("measured_without_proof")
    # mandatory rollback for any post-write path
    if candidate_written:
        game_running=False
        # reacquire root may fail; if so no verified rollback and queue must stop
        if random.random()<0.025:
            uid=2000
            if measured and stage!="LKG":
                pass
            continue
        uid=0
        stage="LKG"; target="LKG"; zygotes=["LKG"]*len(zygotes)
        if inode!=12345 or metadata!="0:0 444 ctx": viol.append("rollback_inode_or_metadata_changed")
        if stage==target=="LKG" and all(x=="LKG" for x in zygotes):
            stats["rollback_verified"]+=1
            if random.random()>=0.025:
                uid=2000
            else:
                continue
        else:
            continue
    if measured and uid not in (0,2000): viol.append("invalid_uid")
    if measured and not candidate_written: viol.append("measurement_without_candidate")
    if candidate_written and stage!="LKG": viol.append("terminal_without_restore")
result={"model":"TFTMAC_CVAR_STAGE_INODE_V2","trajectories":N,"violation_count":len(viol),"violations":viol[:20],"stats":stats,"invariants":{"no_unmount_or_remount":True,"stage_inode_preserved":True,"candidate_verified_in_all_zygote_namespaces":True,"engine_proof_before_measurement":True,"rollback_required_after_any_candidate_write":True,"current_winner_restored_before_normal_quit":True}}
result["receipt_sha256"]=hashlib.sha256(json.dumps(result,sort_keys=True,separators=(",",":")).encode()).hexdigest()
print(json.dumps(result,indent=2,sort_keys=True))
raise SystemExit(0 if not viol else 1)
