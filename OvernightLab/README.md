# TFTMAC OvernightLab

External official-client telemetry and bounded experiment controller for TFTMAC DEV. It reuses `/Applications/TFTMAC DEV.app` and the existing StockShadow runtime; it does not contain or create another app, SDK, emulator, system image, or AVD.

## Current authority

Before interpreting or running OvernightLab, read `facts.md`, `project.md`, and `CHANGELOG.md`. The current working baseline is **`DEV-B8-WIN-01`**:

- official TFT `18.1-5423749` / versionCode `8423749`;
- 1920x1080 / 320 DPI / 60 Hz;
- effective DEV launch **8 vCPU / 6144 MiB** (the static StockShadow restoration file remains 6/5120 and is not the effective launch);
- host GPU / CoreAudio;
- selected game RHI **OpenGL ES through ANGLE**;
- multifile cache enabled;
- `preferSubmitAtFBOBoundary` disabled;
- `syncMonolithicPipelinesToBlobCache` removed.

The frozen Sept-10 LKG remains separate historical/control evidence. OvernightLab must not silently restore the old global-sync property set as the working control.

## Evidence-retention policy

OvernightLab data is **not discarded merely because a historical run differs in CPU count, RAM amount, or another minor configuration field**. Requested and effective values remain useful telemetry and are preserved with provenance.

- Minor configuration drift: preserve telemetry; label it non-comparable/data-only unless a valid matched comparison makes it admissible for the current winner.
- Core client/pipeline mismatch: preserve raw evidence for forensics, but exclude it from current promotion decisions.
- Historical negative result: preserve it and its reason; do not automatically rerun it.
- Verified win: integrate it into the working baseline, then future tests start from that winner.

The candidate manifest keeps resolved candidates as a historical catalog, while the automatic queue contains only the current working control until a new one-factor candidate is deliberately admitted.

## Logging

Raw native capture remains authoritative. OvernightLab supplements it with observed client identity, effective vCPU/RAM/display/GPU, selected RHI and raw classifier, requested/effective guest properties and DeviceProfile CVars, native frame windows and tail/jank data, mechanism events when available, coverage/loss counts, failure fingerprints, rollback/integrity evidence, and evidence provenance including promotion admissibility.

Logging fields that are not currently used for promotion remain valid data and should be retained for later analysis.

## Safety

- Current-client promotion requires the current authority identity; mismatched evidence is retained but not promoted.
- Historical PBE inputs remain decision-inadmissible.
- Candidate rollback is required before another candidate.
- No CAPTCHA/MFA bypass and no blind unknown-screen clicks.
- Profiling traces, if ever used, must be time/buffer bounded under project policy; normal OvernightLab operation does not require unbounded profiling.
- No generalized builder/VM work is part of ordinary testing.

## Commands

`./install.command` installs the small control plane at `/Volumes/MAC MINI M4/TFTMAC/OvernightLab` and compiles only the standalone screen classifier.

`./run-overnight-campaign.command --self-test` runs static and fault-injection acceptance.

`./run-overnight-campaign.command --duration 10h` starts/resumes the currently admitted queue under `caffeinate`.

`python3 overnight_lab.py status` prints the active checkpoint.

`python3 overnight_lab.py report` regenerates reporting from retained lab data.
