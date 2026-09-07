# System

## Implemented capabilities

- `swift run StatusDriver` opens a native SwiftUI window containing a SpriteKit scene.
- A bounded random walk emits normalized metric samples at a regular cadence.
- Samples map to fixed world positions and produce one piecewise-linear point collection used by drawing and collision.
- The viewport advances continuously behind the newest sample, leaving completed terrain beyond the right edge.
- A 60-second rolling buffer retains offscreen history and removes older samples and geometry.
- The scene redraws its graph grid and terrain mapping when the window changes size.
- The current presentation has an off-white graph background, dark terrain line, and translucent fill.
- A small orange chassis and two physical wheels ride on the terrain edge chain.
- `D`/Right drives right, `A`/Left brakes then drives left, and `R` resets the car.
- Leaving any viewport edge fully triggers the same centered, upright reset.

## Entry points

- `Package.swift` defines the core library, application executable, and model-check executable.
- `Sources/StatusDriver/StatusDriver.swift` defines the SwiftUI application and window.
- `Sources/StatusDriver/TerrainView.swift` embeds the SpriteKit scene.
- `Sources/StatusDriver/TerrainScene.swift` schedules samples, moves the viewport, prunes history, handles input, and coordinates vehicle reset.
- `Sources/StatusDriver/Vehicle.swift` builds the chassis, wheels, joints, motors, and vehicle visuals.
- `Sources/StatusDriverCore/DrivingInput.swift` defines the complete key-code mapping.
- `Sources/StatusDriverCore/MetricSample.swift` defines normalized samples and the random source.
- `Sources/StatusDriverCore/RollingSampleBuffer.swift` owns ordered retention and pruning.
- `Sources/StatusDriverCore/TerrainGeometry.swift` maps samples and creates line and fill paths.
- `Sources/StatusDriverModelTests/StatusDriverModelTests.swift` runs automated checks without Xcode test frameworks.

## Runtime flow

1. The SpriteKit scene prefills 60 seconds of synthesized sample history.
2. The source appends another normalized sample every 0.15 seconds.
3. The scene maps retained samples at 120 points per second into its current height.
4. The mapped points replace the visible line, translucent fill, and terrain edge-chain body.
5. The camera moves every rendered frame and trails the newest sample by 2.75 seconds.
6. The buffer keeps one segment crossing its cutoff and removes older points.
7. Held horizontal controls set wheel motor speed before each physics step. No key applies chassis torque.
8. A manual reset or a fully offscreen vehicle replaces the old bodies and joints with an upright vehicle above terrain at window center.

These constants are prototype tuning values rather than stable interfaces.

## Inspection

- Run `swift build` to compile every package target.
- Run `swift run StatusDriverModelTests` to execute normalization, random bounds, retention, point mapping, interpolation, key mapping, and geometry checks.
- Run `swift run StatusDriver` to inspect the complete interaction.
- Verify that `D`/Right drives right and `A`/Left brakes rightward motion before driving left. `W`, `S`, Up, and Down should do nothing.
- Verify that the chassis rotates only in response to terrain and collisions.
- Verify that `R` resets the car and that fully leaving each viewport edge causes the same reset.
- Resize the window and verify that the terrain stays aligned and the car preserves its clearance from the remapped terrain.

## Limitations

- Vehicle feel depends on provisional motor, mass, damping, and wheel-torque constants that still need human tuning.
- The source is synthesized. No CPU or memory telemetry is collected.
- The application has no activity-monitor labels or controls.
- The package targets macOS 26 and has no bundle, signing, or distribution setup.
- This Command Line Tools installation has neither a usable `Testing` module nor `XCTest`. Automated checks therefore use a normal executable target rather than `swift test`.
- SpriteKit may log `SKView: no drawables available` while the window is fully occluded. Rendering resumes when the window becomes visible.
