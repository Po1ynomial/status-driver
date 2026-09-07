# Design

## Application structure

The application uses a native SwiftUI shell with an embedded SpriteKit scene. It remains a Swift Package Manager executable launched with `swift run`.

SwiftUI owns the application lifecycle, telemetry session, source selection, and minimal metric annotation. SpriteKit owns curve rendering, keyboard input, vehicle simulation, and terrain collision. SpriteKit consumes metric readings but never calls Mach APIs or schedules telemetry collection.

The application targets the owner's current macOS 26.2 machine. It may use convenient current APIs and makes no backward-compatibility claim.

## Streaming source boundary

An application-owned source emits normalized metric readings through an asynchronous stream. Each reading contains a monotonic session timestamp, a `Double` value in `0...1`, source identity, and availability state.

A `ContinuousClock` task samples every 150 ms. It starts once for the application session, continues while SpriteKit rendering is throttled or occluded, and cancels when the application session ends. The consumer does not backfill one reading per missed timer deadline. It resumes from the current clock instant, which bounds recovery work after suspension or sleep.

The default source reads aggregate CPU ticks. Passing `--synthetic` selects the bounded random source. Both sources implement the same streaming interface. No runtime failure silently changes the selected source.

## CPU calculation

Read cumulative user, system, idle, and nice ticks with `host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, ...)`. This call is unprivileged on the current machine.

For each pair of successful reads:

1. Compute wrapping deltas for all four counters.
2. Add user, system, and nice deltas as busy ticks.
3. Add busy and idle deltas as total ticks.
4. Divide busy by total and clamp to `0...1`.
5. If no ticks advanced, reuse the last filtered value. Keep it available after at least one valid utilization; startup remains unavailable until a valid utilization exists.

The result is whole-system utilization. A value of `1.0` means all logical CPUs are busy. Status Driver's own work remains part of that total.

Apply a time-aware exponential moving average with a target time constant of roughly 0.75 seconds. The filtered value feeds both terrain and the displayed percentage. Raw readings remain internal for possible later monitor work.

## Startup and failure behavior

The first successful filtered CPU reading prefills the retained terrain window as a flat value. No telemetry persists between launches.

After a failed read, emit the last valid filtered value so terrain and collision stay continuous, but mark the reading unavailable. Before any successful read, use `0.5` as a neutral placeholder. Retry on every 150 ms interval and return to available status after the next successful calculation.

## Rolling terrain

The scene maps streamed samples to fixed horizontal intervals and a configured vertical range. It connects adjacent samples with straight line segments. Drawing and collision construction consume the same mapped points. The SpriteKit stroke uses butt caps and bevel joins because round tessellation produced detached fragments on long, nearly collinear CPU paths.

The viewport advances smoothly with monotonic session time rather than jumping at sample boundaries. It trails the newest sample by a short fixed delay, leaving completed terrain beyond the right edge. Retention also keeps terrain beyond the left edge.

The viewport follows the live data window, not the car. Samples, drawing nodes, and collision geometry far enough behind the left margin are removed together. Retention remains bounded during an indefinite run.

## Vehicle

The car consists of a small chassis and two physical wheels connected by pin joints. It is about 55 percent of the original prototype vehicle size. Wheel torque moves the car along the terrain. The chassis receives no direct control torque, so terrain contact and gravity determine its rotation.

Controls are:

- `Right` or `D`: drive toward the right.
- `Left` or `A`: brake rightward motion, then drive toward the left.
- `R`: reset.

`Up`, `Down`, `W`, and `S` are unbound. Vertical or rotation controls may return later with a matching arrow-key scheme.

Reset removes the existing bodies and joints, then creates an upright vehicle above the terrain at the horizontal center of the current window. The scene invokes the same reset after the full car body leaves any viewport edge.

## Presentation

The application uses a warm off-white background, a faint graph grid, a dark piecewise-linear curve with translucent fill below it, and one high-contrast orange car. It has no game objective or HUD.

A small annotation fixed at the upper-left identifies the metric and current filtered value:

- `CPU n%` while live CPU readings are available.
- `SYNTHETIC n%` in explicit synthetic mode.
- `CPU unavailable` while the CPU source is failing.

This annotation is the full interface scope for telemetry integration. Metric panels, controls, axes, legends, and multi-metric layout remain deferred.

## Inspection and checks

The installed Command Line Tools lack a usable `Testing` or `XCTest` runtime, so `swift run StatusDriverModelTests` runs package-local automated checks. Telemetry checks cover tick delta math, counter rollover, zero-delta intervals, smoothing, source selection, unavailable-value reuse, recovery, and task cancellation.

Manual inspection covers response to generated CPU load, source annotation, explicit synthetic mode, occlusion recovery, bounded retention, smooth scrolling, controls, resets, and resizing.
