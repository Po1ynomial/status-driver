# System

## Implemented capabilities

- `swift run StatusDriver` opens a native SwiftUI window containing a SpriteKit scene.
- A bounded random walk emits normalized metric samples at a regular cadence.
- Samples map to fixed world positions and produce one piecewise-linear point collection used by drawing and collision.
- The viewport advances continuously behind the newest sample, leaving completed terrain beyond the right edge.
- A 60-second rolling buffer retains offscreen history and removes older samples and geometry.
- The scene redraws its graph grid and terrain mapping when the window changes size.
- The current presentation has an off-white graph background, dark terrain line, and translucent fill.

## Entry points

- `Package.swift` defines the core library, application executable, and model-check executable.
- `Sources/StatusDriver/StatusDriver.swift` defines the SwiftUI application and window.
- `Sources/StatusDriver/TerrainView.swift` embeds the SpriteKit scene.
- `Sources/StatusDriver/TerrainScene.swift` schedules samples, moves the viewport, prunes history, and builds scene nodes.
- `Sources/StatusDriverCore/MetricSample.swift` defines normalized samples and the random source.
- `Sources/StatusDriverCore/RollingSampleBuffer.swift` owns ordered retention and pruning.
- `Sources/StatusDriverCore/TerrainGeometry.swift` maps samples and creates line and fill paths.
- `Sources/StatusDriverModelTests/StatusDriverModelTests.swift` runs automated checks without Xcode test frameworks.

## Runtime flow

1. The SpriteKit scene prefills 60 seconds of synthesized sample history.
2. The source appends another normalized sample every 0.15 seconds.
3. The scene maps retained samples at 120 points per second into its current height.
4. The mapped points replace the visible line, translucent fill, and edge-chain collision body.
5. The camera moves every rendered frame and trails the newest sample by 2.75 seconds.
6. The buffer keeps one segment crossing its cutoff and removes older points.

These constants are prototype tuning values rather than stable interfaces.

## Inspection

- Run `swift build` to compile every package target.
- Run `swift run StatusDriverModelTests` to execute normalization, random bounds, retention, point mapping, and geometry checks.
- Run `swift run StatusDriver` to inspect scrolling and resize behavior.
- While the application is visible, verify that the terrain moves smoothly left, new terrain arrives from the right, the fill stays aligned with the line, and resizing remaps the graph without gaps.

## Limitations

- The car, controls, and reset behavior belong to the next implementation slice and are not present.
- The source is synthesized. No CPU or memory telemetry is collected.
- The application has no activity-monitor labels or controls.
- The package targets macOS 26 and has no bundle, signing, or distribution setup.
- This Command Line Tools installation has neither a usable `Testing` module nor `XCTest`. Automated checks therefore use a normal executable target rather than `swift test`.
- SpriteKit may log `SKView: no drawables available` while the window is fully occluded. Rendering resumes when the window becomes visible.
