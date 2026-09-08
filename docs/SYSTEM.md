# System

## Implemented capabilities

- `swift run StatusDriver` opens a native macOS Performance split view and collects aggregate CPU and reclaimability-aware memory concurrently.
- `swift run StatusDriver -- --synthetic` creates independent random CPU and memory channels and marks the sidebar `Synthetic data`.
- The resizable and collapsible sidebar contains only CPU and Memory, with current summaries and 60-second sparklines.
- Clicks and app-wide `1`/`2` shortcuts select the resource and physical terrain.
- The CPU detail page shows chip name, utilization, process and best-effort thread counts, uptime, packages, cores, performance-level topology and caches, logical processors, and virtualization support.
- The Memory detail page shows installed, in-use, available, app, wired, compressed, file-cache, and unified-memory values plus a composition bar.
- CPU uses blue and Memory uses violet across sparklines, graph border, terrain, fill, and composition. The interface follows system light or dark appearance.
- An application-owned asynchronous stream emits paired snapshots every 150 ms independently of SpriteKit rendering.
- CPU uses wrapping Mach tick deltas. Memory uses Mach VM statistics, `hw.memsize`, and `(internal - purgeable + wired + compressor) / physical pages`.
- Each metric has independent availability, a time-aware 0.75-second exponential moving average, and a bounded 60-second history.
- Current values update at 150 ms. Main graphs, sparklines, and collision expose only immutable one-second averages.
- Launch-time hardware metadata and a separate one-second process/thread/uptime stream do not block terrain telemetry.
- An unavailable inactive metric cannot be selected. An active metric remains selected and extends flat terrain while unavailable.
- The main graph maps a 60-second span across its current width with a one-second commit horizon and truthful `61 seconds` and `1 second` labels.
- Five extra seconds of real history support the left boundary. An undrawn flat collision segment supports the right boundary.
- Selection preserves viewport time, replaces drawing and collision geometry, restores graph focus, and resets a visible car.
- The terrain stroke uses butt caps and bevel joins to avoid SpriteKit fragments on long, nearly flat paths.
- The car is hidden on launch. Undisclosed `C` creates or removes the complete physical vehicle inside the graph.

## Entry points

- `Package.swift` defines the core library, application executable, and model-check executable.
- `Sources/StatusDriver/StatusDriver.swift` selects live or synthetic mode, defines the window, and installs app-wide resource shortcuts.
- `Sources/StatusDriver/TelemetrySession.swift` loads hardware metadata, consumes fast and one-second streams, publishes sidebar histories and details, and owns selection state.
- `Sources/StatusDriver/TerrainView.swift` defines the Performance split view, sidebar sparklines, selected-resource detail pages, Memory composition, formatters, and SpriteKit bridge.
- `Sources/StatusDriver/TerrainScene.swift` stores terrain histories, switches graph color and geometry, handles graph keyboard input, and coordinates the vehicle.
- `Sources/StatusDriver/Vehicle.swift` builds the chassis, wheels, joints, motors, and vehicle visuals.
- `Sources/StatusDriverCore/CPUUsage.swift` defines Mach CPU reads, utilization delta math, smoothing, and the CPU producer.
- `Sources/StatusDriverCore/DrivingInput.swift` defines driving, reset, car-toggle input, and vehicle visibility state.
- `Sources/StatusDriverCore/MemoryUsage.swift` defines VM reads, raw and derived Memory details, bounded composition, and the Memory producer.
- `Sources/StatusDriverCore/MetricHistoryStore.swift` owns independent rolling histories and selection rules.
- `Sources/StatusDriverCore/MetricReading.swift` defines metric identity, availability, detail payloads, paired snapshots, source mode, and startup gating.
- `Sources/StatusDriverCore/MetricStream.swift` defines paired producers, clocks, bounded streaming, concurrent live production, and dual synthetic production.
- `Sources/StatusDriverCore/PerformanceDetails.swift` defines hardware profiles, sysctl mapping, process and thread enumeration, uptime, and the one-second secondary stream.
- `Sources/StatusDriverCore/RollingSampleBuffer.swift` owns flat prefill, ordered retention, and pruning for one metric.
- `Sources/StatusDriverCore/TerrainGeometry.swift` maps the 60-second timeline and creates separate visible and collision paths.
- `Sources/StatusDriverModelTests/StatusDriverModelTests.swift` runs automated checks without Xcode test frameworks.

## Runtime flow

1. `StatusDriverApp` parses `--synthetic`; all other launches use genuine telemetry.
2. `TelemetrySession` loads a partial-tolerant hardware profile once.
3. Concurrent live or dual synthetic producers emit paired CPU and Memory readings every 150 ms.
4. The session appends one immutable average per completed second, publishes that committed history for sparklines, and sends the same inputs to SpriteKit. Open buckets remain internal.
5. A separate one-second stream publishes process count, best-effort thread count, and uptime.
6. Native sidebar or command selection updates shared application state, then switches the SpriteKit terrain and graph colors.
7. The detail page reads the selected metric, hardware profile, raw Memory detail, and one-second activity without delaying graph updates.
8. The graph width determines world scale so one viewport always equals 60 seconds. Its right edge follows source time minus one second.
9. Finalized points are created offscreen right and never change after entering view. Collision continues flat for 120 points after the newest committed point, while 65-second retention leaves real terrain left of the viewport.
10. No vehicle exists until `C` toggles visibility. Selection, resize, manual reset, and offscreen reset recreate a visible vehicle at graph center; hidden state stays empty.
11. Horizontal controls use reduced wheel speed and torque for the slower 60-second graph scale.

## Inspection

- Run `swift build` to compile every package target.
- Run `swift run StatusDriverModelTests` to execute terrain, telemetry, detail, hardware, secondary stream, selection, cancellation, and live system checks.
- Run `swift run StatusDriver`; inspect both sidebar rows and detail pages and compare values with `top`, `vm_stat`, and `sysctl` when useful.
- Select CPU and Memory by click and with `1`/`2`; verify the detail page, terrain color, collision, and car reset change together.
- Collapse and restore the sidebar with its native title-bar control. Resize the sidebar and window near their provisional bounds.
- Change system appearance and verify native controls, text, graph, sparklines, composition, and car remain legible.
- Run `swift run StatusDriver -- --synthetic`; verify the marker and both independent histories.
- Confirm no car appears at launch. Focus the graph and press `C` to show or hide it, then inspect `A`/`D`, arrow keys, `R`, selection reset, resize reset, and graph-boundary reset.
- Verify terrain already in view never changes shape and that a car crossing the right edge remains supported until it resets.

## Limitations

- Thread count is best effort and may undercount protected or exiting processes.
- Memory is a project-defined occupancy estimate, not exact Activity Monitor accounting. Pressure and swap are absent.
- The interface has no process list, per-core graph, disk, network, history controls, or persisted telemetry.
- The package targets macOS 26 and has no bundle, signing, or distribution setup.
- This Command Line Tools installation has neither a usable `Testing` module nor `XCTest`. Automated checks use a normal executable target rather than `swift test`.
- SpriteKit may occasionally log `SKView: no drawables available for rendering. Skipping this frame.` A lone skipped-frame diagnostic is harmless when animation and input remain smooth.
