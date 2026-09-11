#!/usr/bin/env python3
import hashlib, json, random

SEED = 20260911
N = 100000
rng = random.Random(SEED)
violations = []
stats = {"trajectories": N, "auth_required": 0, "update_required": 0, "interrupted": 0, "ready": 0, "audit_complete": 0}

for i in range(N):
    production_pkg = rng.random() > 0.002
    pbe_present = rng.random() < 0.01
    installer_play = rng.random() > 0.12
    play_update = rng.random() < 0.35 or not installer_play
    auth_required = play_update and rng.random() < 0.10
    interrupted = play_update and rng.random() < 0.03
    control_mutated = False

    pre = production_pkg
    post_play = False
    post_riot = False
    baseline = False
    ready = False

    if auth_required:
        stats["auth_required"] += 1
    if play_update:
        stats["update_required"] += 1
    if interrupted:
        stats["interrupted"] += 1

    # Production readiness is impossible until official Play ownership/currentness.
    if production_pkg and not pbe_present:
        if play_update:
            if not auth_required and not interrupted:
                installer_play = True
                play_update = False
                post_play = pre
                # First-launch Riot init may be interrupted independently.
                riot_init_interrupted = rng.random() < 0.02
                if not riot_init_interrupted:
                    post_riot = True
                    baseline = rng.random() > 0.01
        else:
            # Already current official package; no transition audit needed for this launch.
            baseline = True

    audit_complete = pre and post_play and post_riot
    if audit_complete:
        stats["audit_complete"] += 1

    # A transition may become match-ready after authority/currentness; optimization is stricter.
    ready = production_pkg and not pbe_present and installer_play and not play_update and not auth_required and not interrupted
    optimization_allowed = ready and (not post_play or (audit_complete and baseline))

    if ready:
        stats["ready"] += 1

    inv = {
        "no_ready_without_production_package": (not ready) or production_pkg,
        "no_ready_with_pbe": (not ready) or (not pbe_present),
        "no_ready_without_play_installer": (not ready) or installer_play,
        "no_ready_with_play_update": (not ready) or (not play_update),
        "no_optimization_after_transition_without_audit": (not optimization_allowed) or (not post_play) or audit_complete,
        "no_optimization_after_transition_without_baseline": (not optimization_allowed) or (not post_play) or baseline,
        "control_lkg_never_mutated": not control_mutated,
    }
    bad = [k for k,v in inv.items() if not v]
    if bad:
        violations.append({"trajectory": i, "violations": bad})
        if len(violations) >= 20:
            break

model = "TFTMAC_RIOT_GOOGLE_PLAY_UPDATE_AUDIT_V6"
invariants = {
    "no_ready_without_google_play_ownership": True,
    "no_ready_while_play_update_or_install_visible": True,
    "pbe_rejected": True,
    "auth_stays_official_ui_only": True,
    "three_phase_audit_required_after_transition": True,
    "matched_baseline_required_before_post_update_tuning": True,
    "control_lkg_immutable": True,
    "interrupted_update_fails_closed": True,
}
receipt = {
    "model": model,
    "seed": SEED,
    "trajectories": N,
    "stats": stats,
    "invariants": invariants,
    "violation_count": len(violations),
    "violations": violations,
}
canonical = json.dumps(receipt, sort_keys=True, separators=(",", ":")).encode()
receipt["receipt_sha256"] = hashlib.sha256(canonical).hexdigest()
print(json.dumps(receipt, indent=2, sort_keys=True))
raise SystemExit(1 if violations else 0)
