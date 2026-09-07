# 0005 - Keep the prototype visually minimal and inspectable

- **Status:** Accepted
- **Date:** 2026-09-07

## Decision

Give the prototype a recognizable activity-graph treatment without designing the eventual monitor interface. Use a warm off-white background, a faint grid, a dark piecewise-linear curve with translucent fill below it, and one high-contrast orange car. Add no labels, metric controls, objectives, or game HUD.

Require the following evidence before the core prototype is complete:

- `swift run` opens a native SwiftUI window on the owner's current Mac.
- Random samples continuously extend terrain while old data and geometry are pruned.
- The viewport scrolls smoothly with collision terrain retained outside both horizontal edges.
- Drawing and collision use the same mapped points.
- The two-wheel car responds to every accepted key binding and receives no direct chassis torque.
- Manual and automatic reset place the car correctly and clear its velocity.
- Window resizing preserves viewport behavior, terrain alignment, and reset placement.
- Package-local automated checks cover sample normalization, rolling retention, geometry generation, and pruning.
- A manual run checks driving feel, scrolling, reset behavior, resizing, and bounded retention.

## Rationale

The graph styling makes the product premise visible without committing to monitor information hierarchy. The orange car remains legible against the graph and reads as a secondary element. Automated checks fit the data and geometry model, while manual inspection is more useful for physics feel and animation quality.

The installed Command Line Tools do not include a usable `Testing` or `XCTest` runtime. The owner accepted `swift run StatusDriverModelTests` as the automated inspection command instead of installing full Xcode solely for `swift test`.

## Consequences

- Finished activity-monitor design remains a later grill slice.
- Physics tuning can change after manual inspection without reopening the control or vehicle model decisions.
- The resizable window is part of prototype completion.
- No release packaging check is required for this milestone.
