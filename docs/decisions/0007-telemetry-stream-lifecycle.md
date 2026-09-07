# 0007 - Own telemetry outside the rendering loop

- **Status:** Accepted
- **Date:** 2026-09-07

## Decision

Replace the SpriteKit-driven pull source with one application-owned asynchronous metric stream. A `ContinuousClock` task emits a reading every 150 ms independently of rendering. SwiftUI owns the session and forwards readings to SpriteKit on the main actor.

Use real CPU telemetry by default. Keep the random source only as an explicit mode selected with `swift run StatusDriver -- --synthetic`.

The first valid filtered reading prefills a flat retained history. Do not persist telemetry between launches.

On a failed CPU read, retry at the next interval and emit the last valid filtered value with unavailable status. Before the first valid reading, use `0.5` as a neutral placeholder. Never switch to random data after a failure.

Cancel the sampling task when the application session ends. After suspension or system sleep, resume at the current clock instant rather than generating one reading for every missed deadline.

## Rationale

SpriteKit throttles rendering when a window is occluded and can skip frames when no Metal drawable is available. A renderer-owned sampler would lose telemetry or generate misleading catch-up samples. Application ownership keeps metric collection independent and lets later monitor views consume the same source.

Reusing a marked stale value keeps the physical terrain continuous. Explicit synthetic selection prevents random terrain from being mistaken for CPU data.

## Consequences

- Source identity and availability travel with normalized readings.
- The scene no longer decides when to collect samples.
- The asynchronous handoff into SpriteKit occurs on the main actor.
- Occlusion does not stop collection, but process termination ends the session.
- Missed deadlines do not create unbounded catch-up work.
- Failure recovery requires no user action.
