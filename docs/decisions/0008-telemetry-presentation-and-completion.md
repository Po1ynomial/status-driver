# 0008 - Identify telemetry without designing the full monitor

- **Status:** Accepted; single-metric annotation extended by [0010](0010-metric-terrain-selection.md)
- **Date:** 2026-09-07

## Decision

Add one small upper-left annotation fixed to the viewport. Show `CPU n%` for available filtered CPU readings, `SYNTHETIC n%` in explicit synthetic mode, and `CPU unavailable` while CPU reads fail.

Defer all other activity-monitor interface design.

[0010](0010-metric-terrain-selection.md) replaces this single-metric annotation with a compact CPU and memory selector while preserving the same minimal-interface intent.

Require this evidence before telemetry integration is complete:

- The default launch uses aggregate CPU data without prompting for permission.
- `--synthetic` selects the random source.
- Sampling proceeds independently of SpriteKit rendering.
- Flat startup history, smoothing, unavailable-value reuse, and recovery follow the accepted rules.
- Automated checks cover tick math, rollover, zero deltas, smoothing, source selection, failure behavior, and cancellation.
- Generating CPU load changes the terrain and percentage within about one second.
- Occluding and restoring the window does not stop collection or cause unbounded catch-up work.
- Existing terrain retention, collision, driving, reset, and resize behavior remain intact.

## Rationale

Without a label, a user cannot tell genuine telemetry from the existing random source or inspect the value mapped into terrain. One annotation establishes that the application is now a monitor without preempting later information hierarchy and GUI work.

## Consequences

- The annotation is monitor information, not a game HUD.
- Metric panels, controls, axes, legends, history navigation, and multi-metric layout remain deferred.
- Available percentages use the same filtered value as the terrain.
- Failure status replaces the percentage rather than displaying stale data as current.
