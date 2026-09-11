# Runtime diagnostic blocker receipt

Date: 2026-09-08
Status: **BLOCKER_CONFIRMED; MINIMUM REPAIR APPLIED**

The second candidate boot reproduced the missing-ready boundary in capture
`2026-09-08T17-12-57.695Z-6a7254c4-00e4-4e54-bd88-f0e8166c5d3b`. Manual guest
verification succeeded and `/proc` mapped the candidate libraries, but the
runtime emitted neither `ANGLE_DRIVER_LOADED_VERIFIED` nor
`TFT_READY_FOR_USER`.

A native sample of the core process showed
`sampleGameFrames -> maintainRiotLoginReliability -> riotSignInSplashDetected`
waiting in `NSConcreteFileHandle readDataOfLength:` while an `adb exec-out
screencap -p` child held its pipe open. This was an actor-isolation/lifecycle
block, not evidence against the ANGLE candidate.

The minimum source repair moves graphics pipeline snapshots and Riot splash /
credential image probes to utility detached tasks. The rebuilt candidate then
recorded `ANGLE_DRIVER_LOADED_VERIFIED` and `TFT_READY_FOR_USER`; no driver
library or graphics setting was altered.
