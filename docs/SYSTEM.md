# System

## Implemented capabilities

- `swift run StatusDriver` opens a native macOS Performance split view and collects aggregate CPU and reclaimability-aware memory concurrently.
- `swift run StatusDriver -- --synthetic` creates deterministic CPU, Memory, Disk 0, Wi-Fi, and GPU sources and marks the sidebar `Synthetic data`.
- The resizable sidebar contains CPU, Memory, discovered whole physical disks, physical Wi-Fi/Ethernet interfaces, and best-effort GPU with current summaries and 60-second sparklines.
- Sidebar clicks are the only resource-selection method.
- The CPU detail page shows chip name, utilization, process and best-effort thread counts, uptime, packages, cores, performance-level topology and caches, logical processors, and virtualization support.
- The Memory detail page shows installed, in-use, available, app, wired, compressed, file-cache, and unified-memory values plus a composition bar.
- Each Disk detail page shows Activity terrain, a current adaptive read/write transfer graph, model, physical capacity, type, root-disk status, response time, byte rates, operation rates, and nonzero errors.
- Each Network detail page uses a current-time adaptive SwiftUI throughput graph with send/receive/combined rates, packet rates, state, BSD interface, addresses, optional link speed, and nonzero errors or drops. Network has no physical terrain.
- GPU appears when current IOKit PerformanceStatistics expose Device Utilization; its detail page shows Device, Renderer, Tiler, in-use system memory, Metal, model, and unified-memory metadata.
- When the hidden global toggle is enabled, Memory replaces the Car with a small sailboat that follows the immutable usage boundary through damped buoyancy and limited slope pitch.
- Disk replaces the Car with a seven-piece Tetromino dropper. The active piece moves and rotates in discrete steps, then becomes a free rigid body when it meets terrain, another piece, or `R`.
- Wi-Fi and non-Thunderbolt Ethernet use a winged Packet in the adaptive Network graph. Space provides one upward impulse; collision attaches it to the struck sample until history carries it offscreen.
- CPU uses blue and Memory uses violet across sparklines, graph border, terrain, fill, and composition. The interface follows system light or dark appearance.
- An application-owned asynchronous stream emits paired snapshots every 150 ms independently of SpriteKit rendering.
- CPU uses wrapping Mach tick deltas. Memory uses Mach VM statistics, `hw.memsize`, and `(internal - purgeable + wired + compressor) / physical pages`.
- Each metric has independent availability, a time-aware 0.75-second exponential moving average, and a bounded 60-second history.
- Current CPU and Memory values update at 150 ms while their graphs expose immutable one-second averages. Disk and GPU graphs commit each filtered one-second reading directly.
- Launch-time hardware metadata and a separate one-second process/thread/uptime stream do not block terrain telemetry.
- An unavailable inactive metric cannot be selected. An active metric remains selected and extends flat terrain while unavailable.
- The main graph maps a 60-second span across its current width with a one-second commit horizon and truthful `61 seconds` and `1 second` labels.
- Five extra seconds of real history support the left boundary. An undrawn flat collision segment supports the right boundary.
- Selection preserves viewport time, replaces drawing and collision geometry, and clears the departing resource's utility objects before creating the selected resource's utility.
- The terrain stroke uses butt caps and bevel joins to avoid SpriteKit fragments on long, nearly flat paths.
- One application-session easter-egg state starts disabled. Undisclosed `C` toggles it globally; CPU and GPU map to Car, Memory to Boat, Disk to Tetromino, Wi-Fi and non-Thunderbolt Ethernet to Packet, and Thunderbolt to None.

## Entry points

- `README.md` is the repository front door: requirements, build and run commands, and the documentation map.
- `Package.swift` defines the core library, application executable, and model-check executable.
- `Sources/StatusDriver/StatusDriver.swift` selects live or synthetic mode and defines the window.
- `Sources/StatusDriver/TelemetrySession.swift` loads hardware metadata, consumes fast and one-second streams, publishes sidebar histories and details, and owns selection state.
- `Sources/StatusDriver/TerrainView.swift` defines the Performance split view, sidebar sparklines, selected-resource detail pages, Memory composition, formatters, and SpriteKit bridge.
- `Sources/StatusDriver/TerrainScene.swift` stores terrain histories, switches graph color and geometry, receives semantic commands, and coordinates Car, Boat, and Tetromino lifecycle.
- `Sources/StatusDriver/Vehicle.swift` builds the chassis, wheels, joints, motors, and vehicle visuals.
- `Sources/StatusDriver/Boat.swift` draws the Memory sailboat and applies the shared buoyancy motion model to SpriteKit coordinates.
- `Sources/StatusDriver/TetrominoPiece.swift` draws controlled tetrominos and converts their four blocks into one compound SpriteKit physics body.
- `Sources/StatusDriverCore/BoatMotion.swift` defines deterministic damped buoyancy, pitch, horizontal sailing, braking, and reset state.
- `Sources/StatusDriverCore/Tetromino.swift` defines the seven shapes, rotation, deterministic seven-piece bag, and normal or accelerated descent cadence.
- `Sources/StatusDriverCore/CPUUsage.swift` defines Mach CPU reads, utilization delta math, smoothing, and the CPU producer.
- `Sources/StatusDriverCore/DrivingInput.swift` defines focus-independent semantic key routing for each easter-egg utility.
- `Sources/StatusDriverCore/DiskPerformance.swift` discovers IOKit whole disks and calculates service-time Activity, transfer, operation, response, error, scale, and identity data.
- `Sources/StatusDriverCore/MemoryUsage.swift` defines VM reads, raw and derived Memory details, bounded composition, and the Memory producer.
- `Sources/StatusDriverCore/GPUPerformance.swift` reads experimental IOKit GPU statistics, clamps/filter values, retries discovery, and exposes GPU details.
- `Sources/StatusDriverCore/NetworkPerformance.swift` maps physical SystemConfiguration ports, reads route-interface counters and getifaddrs addresses, calculates rates, adaptive scale, connection state, and discovery cadence.
- `Sources/StatusDriverCore/NetworkPacket.swift` maps adaptive throughput into graph coordinates and defines Packet spawn, gravity, flap, soft ceiling, swept collision, stuck attachment, rescaling, and autorespawn.
- `Sources/StatusDriverCore/MetricHistoryStore.swift` owns independent rolling histories and selection rules.
- `Sources/StatusDriverCore/MetricReading.swift` defines metric identity, availability, detail payloads, paired snapshots, source mode, and startup gating.
- `Sources/StatusDriverCore/MetricStream.swift` defines paired producers, clocks, bounded streaming, concurrent live production, and dual synthetic production.
- `Sources/StatusDriverCore/PerformanceDetails.swift` defines hardware profiles, sysctl mapping, process and thread enumeration, uptime, and the one-second secondary stream.
- `Sources/StatusDriverCore/PerformanceResource.swift` defines stable dynamic IDs, descriptors, ordering, colors, graph/utility policies, discovery reconciliation, adaptive scale, and global easter-egg state.
- `Sources/StatusDriverCore/SyntheticDiskPerformance.swift` emits deterministic coherent Disk 0 activity and detail data.
- `Sources/StatusDriverCore/SyntheticNetworkPerformance.swift` emits deterministic coherent Wi-Fi throughput and detail data.
- `Sources/StatusDriverCore/SyntheticGPUPerformance.swift` emits deterministic coherent GPU utilization and detail data.
- `Sources/StatusDriverCore/RollingSampleBuffer.swift` owns flat prefill, ordered retention, and pruning for one metric.
- `Sources/StatusDriverCore/TerrainGeometry.swift` maps the 60-second timeline and creates separate visible and collision paths.
- `Sources/StatusDriverModelTests/StatusDriverModelTests.swift` runs automated checks without Xcode test frameworks.

## Runtime flow

1. `StatusDriverApp` parses `--synthetic`; all other launches use genuine telemetry.
2. `TelemetrySession` loads a partial-tolerant hardware profile once.
3. Concurrent live or dual synthetic producers emit paired CPU and Memory readings every 150 ms. All telemetry producers use one shared clock origin.
4. The session appends one immutable CPU and Memory average per completed second. Disk and GPU append each filtered one-second reading directly because those inputs are already at chart cadence. The session publishes the same committed histories to sparklines and SpriteKit.
5. A separate one-second stream publishes process count, best-effort thread count, and uptime.
6. A Disk monitor walks IOKit once per second, refreshes discovered whole-disk identity every five seconds, and publishes reset-safe Activity and transfer details.
7. A Network monitor discovers physical ports every five seconds, reads stable interface counters each second, and publishes current-time adaptive throughput details.
8. A GPU monitor reads experimental IOKit Device/Renderer/Tiler utilization each second and retries missing or failed discovery every five seconds.
9. Native sidebar selection updates shared application state. Physical resources select SpriteKit terrain; Network selects a nonphysical SwiftUI graph.
10. The detail page reads the selected resource, hardware profile, raw details, and supporting current-time graph data without delaying terrain updates.
11. The physical graph width determines world scale so one viewport always equals 60 seconds. Its right edge follows source time minus one second but never advances beyond the selected resource's latest committed point.
12. Finalized physical points are created offscreen right and never change after entering view. Disk and GPU samples no longer wait for a second one-second reading before becoming committed. Collision continues flat for 120 points after the newest committed point, while 65-second retention leaves real terrain left of the viewport.
13. A window-level event monitor converts keys into resource-specific semantic commands without depending on the current first responder. `C` toggles one application-owned session state and dispatches Car, Boat, Tetromino, Packet, or None from the selected descriptor.
14. Car and Boat use held horizontal movement. Tetromino uses repeated discrete movement, accelerated drop, and quarter-turn rotation. Packet uses nonrepeating Space impulses against gravity.
15. Selection, resize, or toggle-off removes transient utility state. Tetromino bodies also leave when fully offscreen and remain capped in number.

## Inspection

- Build with the Xcode developer directory selected. `xcode-select -p` must print `/Applications/Xcode.app/Contents/Developer`. The macOS 27 SDK implements SwiftUI `State` as an external macro, and the Xcode 27 Command Line Tools package ships no `libSwiftUIMacros.dylib`, so a Command Line Tools-only selection fails in `Sources/StatusDriver/TerrainView.swift` with `external macro implementation type 'SwiftUIMacros.StateMacro' could not be found for macro 'State()'; plugin for module 'SwiftUIMacros' not found`. Repair it with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`. Swift Package Manager replanned and rebuilt here without deleting `.build`, so a clean rebuild is only a fallback if the first retry still fails. See [0020](decisions/0020-build-with-the-xcode-toolchain.md).
- Run `swift build` to compile every package target.
- Run `swift run StatusDriverModelTests` to execute terrain, telemetry, detail, hardware, secondary stream, selection, cancellation, and live system checks.
- Run `swift run StatusDriver`; inspect every resource row and compare values with `top`, `vm_stat`, `ioreg`, `iostat`, `netstat`, and `ifconfig` when useful.
- Select resources by click and verify the detail page, graph color, utility dispatch, and cleanup change together. Number keys should not select resources.
- Collapse and restore the sidebar with its native title-bar control. Resize the sidebar and window near their provisional bounds.
- Change system appearance and verify native controls, text, graphs, sparklines, composition, and every utility remain legible.
- Run `swift run StatusDriver -- --synthetic`; verify the marker and both independent histories.
- Watch Disk and GPU for several one-second samples; the terrain line and fill must remain attached to the graph's right edge without a blank sawtooth before each update.
- Confirm no utility appears at launch. Press `C` with the sidebar, graph, and detail values focused; the selected utility must appear without an extra graph click.
- On CPU and GPU, inspect Car movement with `A`/`D` or arrows and `R`.
- On Memory, inspect Boat sailing, braking, buoyancy, pitch, `R`, and boundary reset without any change to the Memory curve.
- On Disk, inspect discrete Tetromino movement, fast drop, quarter-turn rotation, physical conversion, `R` release, pile collision, culling, and complete cleanup after selection or resize.
- On Wi-Fi and non-Thunderbolt Ethernet, inspect Packet gravity, Space impulse, soft ceiling, spike collision, stuck scrolling, autorespawn, `R`, and adaptive rescaling. Thunderbolt must show no utility.
- Verify terrain already in view never changes shape and that a car crossing the right edge remains supported until it resets.

## Limitations

- Thread count is best effort and may undercount protected or exiting processes.
- Memory is a project-defined occupancy estimate, not exact Activity Monitor accounting. Pressure and swap are absent.
- Disk system status assumes the only nonremovable physical disk is the root disk when no direct APFS physical-store mapping is available.
- Wi-Fi SSID, signal, channel, and PHY mode are intentionally absent. Some Ethernet-class physical ports remain visible as disconnected.
- GPU registry keys are experimental and may disappear after a macOS update; the row then omits itself or remains unavailable if selected.
- The interface has no process list, per-core graph, history controls, or persisted telemetry.
- The package declares a macOS 26.0 deployment minimum under `swift-tools-version: 6.3` and builds against the macOS 27.0 SDK with the Xcode 27 toolchain. It has no bundle, signing, or distribution setup.
- Automated checks run as an executable target through `swift run StatusDriverModelTests` rather than `swift test`. Xcode 27 supplies both `Testing` and `XCTest`, so this is a packaging choice rather than a toolchain limitation.
- SpriteKit may occasionally log `SKView: no drawables available for rendering. Skipping this frame.` A lone skipped-frame diagnostic is harmless when animation and input remain smooth.
