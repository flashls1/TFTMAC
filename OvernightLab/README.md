# TFTMAC OvernightLab

Production external control plane for unattended official-client TFT graphics experiments. It deliberately reuses `/Applications/TFTMAC DEV.app` and the existing StockShadow runtime; it does not contain or create another app, SDK, emulator, system image, or AVD.

## Safety / authority

- Current-client evidence only: `com.riotgames.league.teamfighttactics` `18.1-5423749`.
- Frozen Sept-10 LKG and installed DEV key hashes are verified before campaigns.
- Historical PBE inputs are decision-inadmissible and rejected at candidate admission.
- 1920x1080 / 320 DPI / 60 Hz / 8 vCPU / 6144 MiB / host GPU are verified before scoring.
- Candidate rollback is required before the next candidate.
- No CAPTCHA/MFA bypass and no blind unknown-screen clicks.
- The deterministic local supervisor can continue without a live ChatGPT/Clara connection.

## Commands

`./install.command` installs the small control plane at `/Volumes/MAC MINI M4/TFTMAC/OvernightLab` and compiles only the standalone screen classifier.

`./run-overnight-campaign.command --self-test` runs static and fault-injection acceptance.

`./run-overnight-campaign.command --duration 10h` starts/resumes the unattended queue under `caffeinate`.

`python3 overnight_lab.py status` prints the active checkpoint.

`python3 overnight_lab.py report` regenerates morning outputs.

ANGLE observability builds use `angle/build-split-reasons.command` and the existing `/Volumes/MAC MINI M4/TFTMAC/DriverBuildExchange`; TFTMAC itself is not rebuilt.
