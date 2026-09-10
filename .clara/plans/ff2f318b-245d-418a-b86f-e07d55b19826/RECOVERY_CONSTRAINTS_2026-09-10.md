# TFTMAC scope correction — results-first constraint

User-directed scope correction, 2026-09-10.

Effective immediately:

1. Stop building investigation infrastructure. Do not create new app copies, runtime copies, SDK copies, AVDs, builder frameworks, orchestration layers, or generic diagnostic systems merely to test a hypothesis.
2. Work one hypothesis at a time. For each hypothesis: use the smallest existing mechanism, run the shortest decisive test, record YES / NO / INCONCLUSIVE, restore baseline, then move on.
3. Prefer existing installed DEV/LKG, existing preserved driver artifacts, existing scripts, existing telemetry, and existing host tools. Reuse before creating anything.
4. No unrelated engineering fixes. Only repair a defect if it directly prevents the current one-hypothesis test from producing a decision.
5. Profiling traces must be bounded. Any xctrace / Instruments invocation must use an explicit maximum duration such as `--time-limit 60s` or an equivalent bounded circular/ring-buffer configuration. Unbounded trace capture is forbidden.
6. After any Xcode/Instruments/profile run, verify DTServiceHub and related profiling daemons are not orphaned. If the owning profiling session is finished and DTServiceHub remains orphaned, terminate it.
7. Do not start another temporary Linux builder/VM as part of ordinary hypothesis testing. Existing temporary builder state is not part of the product and must not be expanded. Component builds are allowed only when a specific current hypothesis literally cannot be tested using an already-built compatible artifact, and the build must be bounded to that single artifact.
8. No giant candidate matrices. No speculative branches. No generalized test harness expansion.
9. Current accepted CONTROL_GREEN remains valid evidence and should not be rerun unless the tested variable requires a new matched control or baseline drift is proven.
10. Current sequence is results-first: test the simplest available current candidates one by one, compare against the accepted control, and advance or reject immediately.

This file supersedes any earlier plan language that encourages generalized OvernightLab expansion or infrastructure work beyond the minimum required to obtain the next decision-quality result.
