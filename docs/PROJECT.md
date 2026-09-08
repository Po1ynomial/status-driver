# Status Driver

## Goal

Build a standalone macOS activity monitor whose statistical curves also act as terrain for a keyboard-controlled car. The monitor is the primary product. Driving is an optional, surprising interaction rather than a game objective.

## Users

The initial audience is the project's owner. This is a personal, entertaining macOS project rather than a distributed product.

## Current milestone

Add memory telemetry beside aggregate CPU and let the user select which metric becomes terrain. Both metrics remain live, filtered, and retained independently. Keep the interface to one compact selector rather than designing the full monitor.

## In scope

- Concurrent aggregate CPU and whole-system memory collection every 150 ms.
- Reclaimability-aware used-memory estimation from Mach VM statistics and physical memory size.
- Independent smoothing, availability, and rolling history for CPU and memory.
- Mouse and `1`/`2` terrain selection.
- Atomic terrain replacement and car reset when selection changes.
- Dual-channel synthetic mode with a persistent `SYNTHETIC` marker.
- Existing rolling terrain, driving, resize, and reset behavior.

## Out of scope for the current milestone

- Memory category breakdown in the interface.
- Memory pressure state and swap display.
- Per-core CPU, process, disk, or network metrics.
- Persisted telemetry history.
- Full activity-monitor information hierarchy and finished monitor chrome.
- Scoring, timers, fuel, win states, objectives, or a game HUD.
- Application bundling, code signing, notarization, or distribution.
- Compatibility with Macs other than the owner's current machine.

## Constraints

- CPU percentage retains the accepted aggregate non-idle tick calculation.
- Memory percentage is `(internal - purgeable + wired + compressor) / physical pages`, safely clamped to `0...1`.
- File-backed cache, purgeable pages, and swap do not count as used physical memory.
- CPU and memory collection, smoothing, availability, and retained history remain independent.
- Sampling continues while SpriteKit rendering is throttled or occluded.
- Failed telemetry reads never trigger a silent source or terrain switch.
- Drawing and collision geometry derive from the selected metric's same filtered samples.
- Retained samples and scene geometry remain bounded.
- The monitor remains the primary product as the project develops.

## Success conditions

- Default launch collects aggregate CPU and memory concurrently every 150 ms.
- Both metrics apply independent time-aware smoothing with a roughly 0.75-second time constant.
- The upper-left strip displays both values and clearly marks the selected terrain.
- Clicking CPU or memory and pressing `1` or `2` change selection.
- An unavailable unselected metric cannot be selected.
- A selected metric that becomes unavailable remains selected, extends flat terrain, and resumes without an automatic switch or reset.
- Switching metrics preserves viewport time, replaces drawing and collision atomically, and resets the car above window center.
- `--synthetic` supplies two independent random channels and displays a persistent synthetic marker.
- Automated checks cover VM calculation, clamping, smoothing, failure isolation, source selection, independent histories, and selection rules.
- A live smoke check validates a current memory reading from Mach and `hw.memsize`.
- Manual checks cover mouse and keyboard selection, synthetic labeling, car reset on switch, driving on both metrics, resizing, and bounded retention.
- Existing CPU availability behavior and terrain rendering remain regression-free.

## Open questions

- Which system metric should follow memory, if any?
- What memory breakdown or pressure information belongs in the full monitor?
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
- [Estimate reclaimability-aware used memory](decisions/0009-memory-telemetry.md)
- [Select terrain from a compact metric strip](decisions/0010-metric-terrain-selection.md)
