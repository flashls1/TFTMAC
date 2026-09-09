# Trace admission receipt: source-instrumented host with TFT

**Scope:** diagnostic-only launch of the existing source-instrumented gfxstream
runtime against an isolated cloned AVD, followed by starting the installed TFT
package. This test does not change the DEV runtime authority and is not a
performance comparison.

**Observed:** 2026-09-09 (local Mac, America/Chicago)

## Decision-critical test

The decision was whether the current TFT process emits the timeline sideband
that the existing host recorder consumes. The host runtime was launched with
`TFTMAC_PIPELINE_EVENT_V1=1` and a new private events directory. After boot, the
installed TFT package was started and the event directory was checked for a
sealed segment. The owned emulator was then terminated and its cloned AVD was
left outside the stock-shadow authority.

## Evidence

- Isolated runtime root:
  `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r1`
- Instrumented emulator:
  `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Install/causal-instrumented-20260903/emulator/emulator`
- Instrumented gfxstream backend SHA-256:
  `10b52fc43a050c5b3693345a40a949c3d75fa30ca303de7dfd88bef5ce287b5d`
- Instrumented runtime advertised `TFTPIPE1` and
  `TFTMAC_PIPELINE_EVENT_V1` strings, and the emulator log loaded gfxstream
  and created Vulkan instances for
  `com.riotgames.league.teamfighttactics` using ANGLE.
- Cloned AVD: `TFTMAC_CausalTrace_R1`; launch used 1920×1080, 60 Hz, six
  vCPUs, 6144 MiB, GuestAngle/Vulkan and `-qt-hide-window`.
- TFT was the focused `GameActivity` after package launch; it was the actual
  installed TFT process, not the owned probe.
- Event directory:
  `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/CausalTrace/20260909-r1/capture/events`
  existed with mode `0700` and contained **zero** `TFTPIPE1` segment files.
- No causal event segment or marker was present in the host stdout/stderr
  capture. The result was the same after waiting 30 seconds after TFT launch.
- The run used no DEV app, no Control runtime, no credentials, and no source
  or registry mutation.

## Result

`INCONCLUSIVE_FOR_TFT_CAUSALITY; GUEST_MARKER_MISSING`

The source-instrumented host path is loadable and the current TFT process does
create an ANGLE Vulkan instance, but the existing instrumentation only records
submissions carrying the owned-probe timeline sideband. TFT emitted no such
sideband in this test. Therefore the host decoder and MoltenVK hooks cannot yet
associate a real TFT submission with a transport or presentation identity. The
owned-probe trace remains a stack-capability check, not TFT evidence.

The smallest next implementation is guest ANGLE submission instrumentation (or
an equivalent GLES/ANGLE identity carrier) in the isolated source runtime. It
must be gated, preserve normal submissions when disabled, and be followed
immediately by the same short TFT event-admission test. No buffer-view,
storage-buffer, fence, or router optimization is justified until that test
produces a current TFT event segment.
