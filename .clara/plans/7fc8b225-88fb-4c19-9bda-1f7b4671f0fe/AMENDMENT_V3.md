# Amendment V3 — bounded zygote mount convergence

## Trigger
A fresh unchanged `DEV-B8-WIN-01` control failed before LKG readiness even though rollback and both installed DEV/frozen LKG integrity passed. The native profile transaction successfully created and mounted the verified LKG profile in the root namespace, then immediately failed one enumerated high-numbered `zygote64` PID (`3172`) because that namespace did not yet contain the target path. Historical successful receipts prove this is not a categorical multi-zygote incompatibility: a prior accepted session verified two zygote64 PIDs (`505 3186`) and proceeded normally, while most accepted boots verified one low-numbered zygote. The high-numbered secondary PID is therefore a drift-sensitive namespace-convergence condition, not evidence that the LKG profile or normal runtime is invalid.

## Classification
BLOCKING DEPENDENCY / startup sequencing detail. Candidate impact measurement cannot be trusted until the unchanged LKG control can enter its verified mount consistently. This does not authorize a new runtime, AVD, profile family, or candidate.

## Smallest correct repair
Keep the existing native profile transaction, existing bind mount, existing target, existing LKG bytes, and existing rollback. Replace the one-shot `pidof zygote64` namespace assertion with a bounded convergence check:

1. Root namespace mount SHA/metadata/context must already be verified exactly as today.
2. Re-enumerate the current `zygote64` process set on every poll; do not preserve a disappeared PID as a permanent blocker and do not ignore a newly appearing current PID.
3. For each current zygote PID, verify the process still exists and its mount namespace sees the exact expected target SHA. Missing target or transient `nsenter` failure is retryable only inside this bounded convergence window.
4. Require the complete current zygote set to pass on two consecutive polls before emitting `MOUNT_VERIFIED`. This prevents a momentary single-view pass from racing a newly appearing secondary zygote.
5. Bound the convergence window to 15 seconds with 250 ms polling. If the complete current set never converges, fail closed before TFT launch and preserve the existing rollback path.
6. Do not perform per-zygote mount operations, do not create another target, and do not weaken SELinux, ownership, metadata, SHA, process-stop, or rollback checks.
7. Because the bundled transaction bytes change, update only the current DEV transaction hash/source receipt, rebuild and install DEV only, and keep the frozen LKG app/hashes untouched.
8. After installation, require protected Control hashes unchanged, current DEV/frozen LKG integrity PASS, then run repeated unchanged WIN-01 controls before restarting candidate measurements.

## ZenGate
PASS only with ZenMC V3 PASS. The simpler one-shot assertion is disproven by observed intermittent secondary-zygote timing. A bounded re-enumerating convergence check is strictly smaller than explicit per-namespace mounting and preserves the existing canonical mechanism and rollback semantics.

## Acceptance
- 100,000-trajectory ZenMC V3 with zero safety violations.
- Source verifier PASS.
- Rebuilt DEV-only installation with protected Control/LKG untouched.
- At least three consecutive unchanged WIN-01 control boots reach LKG readiness/playable stage measurement with rollback verified before candidate work resumes.
- Candidate measurement remains forbidden until effective CVar proof and normal RHI identity pass.
