# System

## Implemented capabilities

- `swift run StatusDriver` opens one native SwiftUI window and collects aggregate CPU and reclaimability-aware memory concurrently.
- `swift run StatusDriver -- --synthetic` creates independent random CPU and memory channels with a persistent `SYNTHETIC` marker.
- An application-owned asynchronous stream emits paired snapshots every 150 ms independently of SpriteKit rendering.
- CPU uses wrapping Mach tick deltas. Memory uses Mach VM statistics, `hw.memsize`, and `(internal - purgeable + wired + compressor) / physical pages`.
- Each metric has independent availability, a time-aware 0.75-second exponential moving average, and a bounded 60-second history.
- Successful CPU snapshots with no changed ticks reuse the last value without flashing unavailable. Actual read failures retain stale values and mark only the affected metric unavailable.
- A compact upper-left strip displays both metrics and marks the selected terrain. Clicks and `1`/`2` select CPU or memory.
- An unavailable inactive metric cannot be selected. An active metric remains selected and extends flat terrain while unavailable.
- Selection preserves viewport time, replaces drawing and collision geometry from the chosen history, and resets the car above window center.
- The viewport advances continuously behind newest samples and retains completed terrain beyond the right edge.
- The terrain stroke uses butt caps and bevel joins to avoid SpriteKit fragments on long, nearly flat paths.
- A small orange chassis and two physical wheels ride on the selected terrain.
- `D`/Right drives right, `A`/Left brakes then drives left, and `R` resets the car.
- Leaving any viewport edge fully triggers the same centered, upright reset.

## Entry points

- `Package.swift` defines the core library, application executable, and model-check executable.
- `Sources/StatusDriver/StatusDriver.swift` selects live or synthetic mode and defines the single SwiftUI window.
- `Sources/StatusDriver/TelemetrySession.swift` consumes paired snapshots, gates metric startup, owns selection state, and forwards both histories to the scene.
- `Sources/StatusDriver/TerrainView.swift` embeds SpriteKit and renders the clickable metric selector.
- `Sources/StatusDriver/TerrainScene.swift` stores metric histories, switches terrain, moves the viewport, handles keyboard input, and coordinates vehicle reset.
- `Sources/StatusDriver/Vehicle.swift` builds the chassis, wheels, joints, motors, and vehicle visuals.
- `Sources/StatusDriverCore/CPUUsage.swift` defines Mach CPU reads, utilization delta math, smoothing, and the CPU producer.
- `Sources/StatusDriverCore/DrivingInput.swift` defines the driving and reset key mapping.
- `Sources/StatusDriverCore/MemoryUsage.swift` defines VM and physical-memory reads, bounded memory arithmetic, and the memory producer.
- `Sources/StatusDriverCore/MetricHistoryStore.swift` owns independent rolling histories, selection rules, and `1`/`2` mapping.
- `Sources/StatusDriverCore/MetricReading.swift` defines metric identity, availability, paired snapshots, source mode, and startup gating.
- `Sources/StatusDriverCore/MetricSample.swift` defines normalized terrain samples and the bounded random walk.
- `Sources/StatusDriverCore/MetricStream.swift` defines paired producers, clocks, bounded streaming, concurrent live production, and dual synthetic production.
- `Sources/StatusDriverCore/RollingSampleBuffer.swift` owns flat prefill, ordered retention, and pruning for one metric.
- `Sources/StatusDriverCore/TerrainGeometry.swift` maps selected samples and creates line and fill paths.
- `Sources/StatusDriverModelTests/StatusDriverModelTests.swift` runs automated checks without Xcode test frameworks.

## Runtime flow

1. `StatusDriverApp` parses `--synthetic`; all other launches use genuine telemetry.
2. `TelemetrySession` creates concurrent live producers or two independent synthetic producers and starts one bounded 150 ms stream.
3. Each snapshot contains CPU and memory readings with the same monotonic timestamp.
4. Each producer applies its own calculation, smoothing, stale-value handling, and availability state.
5. Independent startup gates normally wait for each metric's first valid value. Persistent failure starts neutral history after 0.3 seconds.
6. The session sends both accepted readings to `TerrainScene` and publishes current values to the selector.
7. The scene prefills each metric's 60-second history independently, then appends and prunes both buffers on one timeline.
8. The selected history produces the line, fill, and collision edge from the same mapped points.
9. The camera interpolates between snapshot arrivals and trails newest samples by 2.75 seconds.
10. A permitted selection changes application and scene state, rebuilds selected terrain, and recreates the car at window center.
11. Held horizontal controls set wheel motor speed before each physics step. Manual or offscreen reset recreates the vehicle in place.

The sample cadence, smoothing interval, viewport delay, terrain scale, and physics constants are prototype tuning values rather than stable interfaces.

## Inspection

- Run `swift build` to compile every package target.
- Run `swift run StatusDriverModelTests` to execute terrain, CPU and memory math, smoothing, failure isolation, dual histories, selection, scheduling, cancellation, and live Mach checks.
- Run `swift run StatusDriver`; verify CPU and memory update together without permission prompts.
- Click both metric items and use `1`/`2`; verify the selected styling, terrain replacement, and centered car reset.
- Run `swift run StatusDriver -- --synthetic`; verify the persistent marker and independent random channels.
- Generate temporary CPU load and verify only CPU responds sharply. Memory should change according to current VM accounting.
- Occlude and restore the window; verify both values advanced without catch-up bursts.
- Verify driving, manual reset, automatic reset, and resizing on both terrains.

## Limitations

- Memory is one project-defined occupancy estimate. It does not claim exact parity with Activity Monitor and does not show category breakdown, pressure, or swap.
- There is no per-core, process, disk, or network telemetry.
- The interface has only the compact metric strip, with no axes, legends, history controls, or full activity-monitor layout.
- Telemetry history exists only for the current process and is not persisted.
- Failure presentation has model coverage but no user-facing failure injection command.
- The package targets macOS 26 and has no bundle, signing, or distribution setup.
- This Command Line Tools installation has neither a usable `Testing` module nor `XCTest`. Automated checks use a normal executable target rather than `swift test`.
- SpriteKit may occasionally log `SKView: no drawables available for rendering. Skipping this frame.` A lone skipped-frame diagnostic is harmless when animation and input remain smooth.
