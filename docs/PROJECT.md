# Status Driver

## Goal

Build a standalone macOS activity monitor whose statistical curves also act as terrain for a keyboard-controlled car. The monitor is the primary product. Driving is an optional, surprising interaction rather than a game objective.

## Users

The initial audience is the project's owner. This is a personal, entertaining macOS project rather than a distributed product.

## Current milestone

Build an objective-free prototype in which synthesized metric samples continuously extend a scrolling terrain curve. Use it to test whether driving directly on a statistical curve is understandable and enjoyable before adding monitor interface design or operating-system telemetry.

## In scope

- A native macOS application run from source.
- One synthesized rolling metric rendered as physical terrain.
- A small two-wheel car controlled horizontally by `A`/`D` or the left/right arrow keys.
- Manual and automatic vehicle reset.
- A replaceable normalized sample-source boundary.
- Bounded retention of terrain data and collision geometry.

## Out of scope for the current milestone

- Genuine operating-system telemetry.
- Activity-monitor information hierarchy and finished monitor chrome.
- Scoring, timers, fuel, win states, objectives, or a game HUD.
- Application bundling, code signing, notarization, or distribution.
- Compatibility with Macs other than the owner's current machine.
- Overlaying or reading another application's pixels.

## Constraints

- The application must derive drawing and collision geometry from the same sampled curve.
- The viewport follows the live data window rather than the car.
- Terrain must remain available outside both visible horizontal edges until the car resets.
- Retained samples and scene geometry must remain bounded during indefinite generation.
- Synthetic input must be replaceable without redesigning terrain interaction.
- The monitor must remain the primary product as the project develops.

## Success conditions

- `swift run` opens a native SwiftUI window containing the SpriteKit prototype on the owner's current Mac.
- A prefetched bounded-random stream continuously adds piecewise-linear terrain to the right.
- The viewport scrolls continuously behind the newest samples, retains collision terrain beyond both sides, and prunes old terrain.
- The visible curve and collision edge use the same sample geometry.
- A small chassis with two physical wheels responds to `A`/`D` and the left/right arrow keys without direct rotation controls.
- `R` and leaving the viewport reset the car upright above the terrain at window center with velocity cleared.
- Resizing preserves the live viewport, terrain alignment, and reset position.
- Package-local automated checks cover sample normalization, rolling retention, geometry generation, and pruning.
- A manual run verifies driving, continuous scrolling, resets, resize behavior, and bounded retention.
- The prototype has no game objectives or HUD.

## Open questions

- Which CPU and memory measurements should the real monitor collect?
- What information hierarchy and visual design should the activity monitor use?
- When, if ever, should the project add application packaging and distribution?

## Accepted decisions

- [Frame the product as an interactive activity monitor](decisions/0001-product-framing.md)
- [Use native frameworks and source-run delivery](decisions/0002-prototype-platform-and-delivery.md)
- [Model terrain as a rolling sample stream](decisions/0003-rolling-terrain-model.md)
- [Use a two-wheel keyboard-controlled car](decisions/0004-driving-interaction.md)
- [Keep the prototype visually minimal and inspectable](decisions/0005-prototype-presentation-and-completion.md)
