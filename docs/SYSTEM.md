# System

## Implemented capabilities

- `swift run StatusDriver` opens one native SwiftUI window, collects CPU and memory concurrently, and uses aggregate CPU as terrain.
- `swift run StatusDriver -- --synthetic` creates independent random CPU and memory channels while keeping synthetic CPU as the visible terrain.
- An application-owned asynchronous stream emits paired snapshots every 150 ms independently of SpriteKit rendering.
- CPU readings use unprivileged Mach host statistics, wrapping tick deltas, and a time-aware 0.75-second exponential moving average.
- Memory readings use unprivileged Mach VM statistics, `hw.memsize`, the accepted reclaimability-aware formula, and an independent 0.75-second moving average.
- Normal CPU startup waits for the first calculated utilization before prefilling flat terrain. Persistent startup failure opens with a neutral value after 0.3 seconds.
- Successful CPU snapshots with no changed ticks reuse the last value without flashing unavailable.
- Failed Mach calls reuse the last filtered value with unavailable status and retry without changing source mode.
- The upper-left annotation shows `CPU n%`, `SYNTHETIC n%`, or `CPU unavailable`.
- Stream, sample, drawing, and collision retention remain bounded.
- The viewport advances continuously behind the newest sample and retains completed terrain beyond the right edge.
- The terrain stroke uses butt caps and bevel joins to avoid SpriteKit fragments on long, nearly flat paths.
- A small orange chassis and two physical wheels ride on the terrain edge chain.
- `D`/Right drives right, `A`/Left brakes then drives left, and `R` resets the car.
- Leaving any viewport edge fully triggers the same centered, upright reset.

## Entry points

- `Package.swift` defines the core library, application executable, and model-check executable.
- `Sources/StatusDriver/StatusDriver.swift` selects the source mode and defines the single SwiftUI window.
- `Sources/StatusDriver/TelemetrySession.swift` creates and consumes the application-owned metric stream.
- `Sources/StatusDriver/TerrainView.swift` embeds SpriteKit and renders the source/value annotation.
- `Sources/StatusDriver/TerrainScene.swift` ingests readings, moves the viewport, prunes history, handles input, and coordinates vehicle reset.
- `Sources/StatusDriver/Vehicle.swift` builds the chassis, wheels, joints, motors, and vehicle visuals.
- `Sources/StatusDriverCore/CPUUsage.swift` defines Mach CPU reads, utilization delta math, smoothing, and the CPU producer.
- `Sources/StatusDriverCore/DrivingInput.swift` defines the complete key-code mapping.
- `Sources/StatusDriverCore/MemoryUsage.swift` defines VM and physical-memory reads, bounded memory arithmetic, and the memory producer.
- `Sources/StatusDriverCore/MetricReading.swift` defines metric identity, availability, paired snapshots, source selection, and startup gating.
- `Sources/StatusDriverCore/MetricSample.swift` defines normalized terrain samples and the bounded random walk.
- `Sources/StatusDriverCore/MetricStream.swift` defines paired producers, clocks, bounded asynchronous streaming, concurrent live production, and dual synthetic production.
- `Sources/StatusDriverCore/RollingSampleBuffer.swift` owns flat prefill, ordered retention, and pruning.
- `Sources/StatusDriverCore/TerrainGeometry.swift` maps samples and creates line and fill paths.
- `Sources/StatusDriverModelTests/StatusDriverModelTests.swift` runs automated checks without Xcode test frameworks.

## Runtime flow

1. `StatusDriverApp` parses `--synthetic`; all other launches select CPU.
2. `TelemetrySession` creates either concurrent live producers or two independent synthetic producers and starts a bounded 150 ms stream.
3. Each stream item has CPU and memory readings with the same monotonic timestamp.
4. The CPU producer calculates aggregate non-idle utilization from tick deltas. The memory producer calculates reclaimability-aware used pages from VM statistics and physical page count.
5. Each producer applies independent time-aware smoothing and availability handling.
6. The CPU startup gate waits for the first calculated terrain value. Synthetic mode starts immediately, while persistent CPU failure starts neutral terrain after 0.3 seconds.
7. The main-actor session retains both latest readings but sends only CPU to `TerrainScene` during this slice.
8. The scene prefills 60 seconds of flat history from its first reading, then appends and prunes streamed samples.
9. The scene maps retained samples at 120 points per second into its current height and rebuilds the line, fill, and collision edge from the same points.
10. The camera interpolates between reading arrivals and trails the newest sample by 2.75 seconds.
11. Held horizontal controls set wheel motor speed before each physics step. Manual or offscreen reset replaces the vehicle bodies and joints at window center.

The sample cadence, smoothing interval, viewport delay, terrain scale, and physics constants are prototype tuning values rather than stable interfaces.

## Inspection

- Run `swift build` to compile every package target.
- Run `swift run StatusDriverModelTests` to execute terrain, CPU and memory math, arithmetic bounds, smoothing, failure isolation, dual synthetic production, source selection, startup, scheduling, cancellation, and live Mach checks.
- Run `swift run StatusDriver` and verify the annotation says `CPU n%` without a permission prompt.
- Generate temporary CPU load and verify the percentage and delayed terrain respond within about one second.
- Run `swift run StatusDriver -- --synthetic` and verify the annotation and terrain identify synthetic mode.
- Occlude the window for several seconds, restore it, and verify telemetry advanced without a burst of catch-up samples.
- Verify driving, reset, and resizing in both source modes.

## Limitations

- Memory is collected but is not yet displayed or usable as terrain. The next slice adds selection and independent histories.
- There is no per-core, process, disk, or network telemetry.
- The interface still contains one CPU/source annotation and no metric selector, axes, legends, or full activity-monitor layout.
- Telemetry history exists only for the current process and is not persisted.
- CPU failure presentation has model coverage but no user-facing failure injection command.
- The package targets macOS 26 and has no bundle, signing, or distribution setup.
- This Command Line Tools installation has neither a usable `Testing` module nor `XCTest`. Automated checks use a normal executable target rather than `swift test`.
- SpriteKit may occasionally log `SKView: no drawables available for rendering. Skipping this frame.` A lone skipped-frame diagnostic is harmless when animation and input remain smooth.
