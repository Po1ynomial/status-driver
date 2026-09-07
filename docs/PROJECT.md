# Status Driver

## Goal

Build a standalone macOS activity monitor whose statistical curves also act as terrain for a keyboard-controlled car. The monitor is the primary product. Driving is an optional, surprising interaction rather than a game objective.

## Users

The initial audience is the project's owner. This is a personal, entertaining macOS project rather than a distributed product.

## Current milestone

Replace synthesized terrain with genuine aggregate CPU utilization while retaining synthetic mode for development. Sampling must continue independently of SpriteKit rendering, and a minimal annotation must identify the active source and current value.

## In scope

- Aggregate system CPU utilization from unprivileged Mach host statistics.
- A 150 ms application-owned asynchronous sample stream.
- A short exponential moving average used by terrain and annotation.
- Flat startup history derived from the first valid reading.
- Explicit synthetic mode through `--synthetic`.
- Visible source, value, and unavailable status.
- Existing rolling terrain, driving, resize, and reset behavior.

## Out of scope for the current milestone

- Per-core CPU data.
- RAM, swap, memory pressure, process, disk, or network metrics.
- Persisted telemetry history.
- Activity-monitor information hierarchy and finished monitor chrome.
- Scoring, timers, fuel, win states, objectives, or a game HUD.
- Application bundling, code signing, notarization, or distribution.
- Compatibility with Macs other than the owner's current machine.

## Constraints

- CPU percentage means non-idle aggregate ticks divided by all aggregate ticks. Full saturation across all logical CPUs maps to `1.0`.
- The application includes its own CPU use in the system total.
- Sampling continues while SpriteKit rendering is throttled or occluded.
- Failed telemetry reads never trigger a silent switch to synthetic data.
- Drawing and collision geometry derive from the same filtered samples.
- Terrain remains available outside both visible horizontal edges until the car resets.
- Retained samples and scene geometry remain bounded.
- The monitor remains the primary product as the project develops.

## Success conditions

- `swift run StatusDriver` uses aggregate CPU data without a permission prompt or entitlement.
- `swift run StatusDriver -- --synthetic` uses the bounded random source.
- The application samples every 150 ms independently of SpriteKit rendering.
- CPU utilization correctly handles cumulative tick deltas, counter rollover, and zero-delta intervals.
- A roughly 0.75-second exponential moving average feeds terrain and the displayed percentage.
- The first valid reading creates flat startup history and no data persists between launches.
- The upper-left annotation shows `CPU n%`, `SYNTHETIC n%`, or `CPU unavailable`.
- Failed reads reuse the last valid terrain value, retry automatically, and recover without changing source mode.
- Automated checks cover tick math, rollover, zero deltas, smoothing, source selection, failure behavior, and cancellation.
- Generating CPU load changes the graph and displayed percentage within about one second.
- Occluding and restoring the window does not stop collection or cause unbounded catch-up work.
- Existing scrolling, pruning, collision, driving, resizing, and reset behavior remain intact.

## Open questions

- Which memory measurement should follow CPU, if any?
- Which other system metrics belong in the monitor?
- How should users select terrain when the monitor displays multiple metrics?
- What information hierarchy and visual design should the full activity monitor use?
- When, if ever, should the project add application packaging and distribution?

## Accepted decisions

- [Frame the product as an interactive activity monitor](decisions/0001-product-framing.md)
- [Use native frameworks and source-run delivery](decisions/0002-prototype-platform-and-delivery.md)
- [Model terrain as a rolling sample stream](decisions/0003-rolling-terrain-model.md)
- [Use a small two-wheel horizontally controlled car](decisions/0004-driving-interaction.md)
- [Keep the prototype visually minimal and inspectable](decisions/0005-prototype-presentation-and-completion.md)
- [Use aggregate CPU utilization for genuine terrain](decisions/0006-aggregate-cpu-terrain.md)
- [Own telemetry outside the rendering loop](decisions/0007-telemetry-stream-lifecycle.md)
- [Identify telemetry without designing the full monitor](decisions/0008-telemetry-presentation-and-completion.md)
