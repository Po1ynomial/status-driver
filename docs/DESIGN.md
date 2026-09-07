# Design

## Application structure

The application uses a native SwiftUI shell with an embedded SpriteKit scene.

SwiftUI owns the macOS application lifecycle and, in later milestones, the activity-monitor interface. SpriteKit owns curve rendering, keyboard input, vehicle simulation, and terrain collision. The first milestone is a Swift Package Manager executable launched with `swift run`.

The prototype targets the owner's current macOS 26.2 machine. It may use convenient current APIs and makes no backward-compatibility claim.

## Sample-source boundary

Metric producers emit normalized samples through a replaceable source interface. Each sample contains a monotonic timestamp and a `Double` value in `0...1`.

The first source emits an indefinite bounded random walk. A later CPU or memory source can replace it without taking responsibility for viewport layout, terrain drawing, or physics.

The scene maps samples to fixed horizontal intervals and a configured vertical range. It connects adjacent samples with straight line segments. Drawing and collision construction consume the same mapped points.

## Rolling terrain

The source prefills enough history and right-side margin before driving begins. It then appends samples continuously at a regular cadence.

The viewport advances smoothly with time rather than jumping at sample boundaries. It trails the newest sample by a short fixed delay, leaving completed terrain beyond the right edge. Retention also keeps terrain beyond the left edge. Exact cadence, delay, spacing, and margin sizes are tuning values chosen during implementation.

The viewport follows the live data window, not the car. Samples, drawing nodes, and collision geometry far enough behind the left margin are removed together. Retention must remain bounded during an indefinite run.

## Vehicle

The car consists of a small chassis and two physical wheels connected by pin joints. It is about 55 percent of the original prototype vehicle size. Wheel torque moves the car along the terrain. The chassis receives no direct control torque, so terrain contact and gravity determine its rotation.

Controls are:

- `Right` or `D`: drive toward the right.
- `Left` or `A`: brake rightward motion, then drive toward the left.
- `R`: reset.

`Up`, `Down`, `W`, and `S` are unbound. Vertical or rotation controls may return later with a matching arrow-key scheme.

Reset removes the existing bodies and joints, then creates an upright vehicle above the terrain at the horizontal center of the current window. Rebuilding avoids stale joint-solver impulses while clearing all motion. The scene invokes the same reset after the full car body leaves any viewport edge. Offscreen terrain margins preserve collision support before that reset.

## Presentation

The prototype uses a warm off-white background, a faint graph grid, a dark piecewise-linear curve with translucent fill below it, and one high-contrast orange car. It has no metric labels, monitor controls, game objectives, or HUD.

The window is resizable. Resizing updates viewport calculations, terrain alignment, offscreen margins, and the reset position without rebuilding the data source.

## Inspection and checks

The installed Command Line Tools lack a usable `Testing` or `XCTest` runtime, so a package-local executable runs the automated model checks. `swift run StatusDriverModelTests` covers normalized sample handling, rolling retention, point mapping, shared draw-and-collision geometry, and pruning.

Physics feel, smooth scrolling, controls, automatic and manual reset, resizing, and bounded retention receive a manual run check.
