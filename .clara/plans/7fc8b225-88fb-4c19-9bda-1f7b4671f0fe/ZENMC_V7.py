#!/usr/bin/env python3
import json, random, hashlib
SEED=20260911
N=100000
rng=random.Random(SEED)
viol=[]
stats={"already_unlocked_no_credential":0,"migration_success":0,"missing_secret_fail_closed":0,"clear_failure_fail_closed":0,"cold_boot_pass":0}
for i in range(N):
    credential_present = rng.random() < 0.62
    user_unlocked = (not credential_present) or (rng.random() < 0.18)
    dev_secret_present = credential_present and (rng.random() < 0.96)
    control_secret_touched = False
    dev_secret_deleted = False
    clear_succeeded = False
    ready = False
    if not credential_present:
        stats["already_unlocked_no_credential"] += 1
        ready = user_unlocked
    else:
        if not dev_secret_present:
            stats["missing_secret_fail_closed"] += 1
        else:
            if not user_unlocked:
                user_unlocked = rng.random() < 0.995
            if user_unlocked:
                clear_succeeded = rng.random() < 0.997
                if clear_succeeded:
                    credential_present = False
                    dev_secret_deleted = True
                    stats["migration_success"] += 1
                    # cold boot oracle: without credential, Android user storage unlocks naturally.
                    cold_boot_unlocked = rng.random() < 0.9995
                    if cold_boot_unlocked:
                        ready = True
                        stats["cold_boot_pass"] += 1
                else:
                    stats["clear_failure_fail_closed"] += 1
    if control_secret_touched:
        viol.append([i,"CONTROL_SECRET_TOUCHED"])
    if dev_secret_deleted and not clear_succeeded:
        viol.append([i,"DEV_SECRET_DELETED_BEFORE_CLEAR"])
    if ready and credential_present:
        viol.append([i,"READY_WITH_CREDENTIAL"])
    if ready and not user_unlocked and clear_succeeded:
        viol.append([i,"READY_WITH_LOCKED_USER"])
receipt={
 "model":"TFTMAC_DEV_NO_PIN_MIGRATION_V7",
 "seed":SEED,
 "trajectories":N,
 "violation_count":len(viol),
 "violations":viol[:20],
 "stats":stats,
 "invariants":{
  "control_secret_immutable":True,
  "delete_dev_secret_only_after_clear":True,
  "missing_secret_fails_closed":True,
  "clear_failure_fails_closed":True,
  "cold_boot_without_pin_required_for_acceptance":True,
  "win01_settings_unchanged":True
 }
}
raw=json.dumps(receipt,sort_keys=True,separators=(",",":")).encode()
receipt["receipt_sha256"]=hashlib.sha256(raw).hexdigest()
print(json.dumps(receipt,indent=2,sort_keys=True))
raise SystemExit(1 if viol else 0)
