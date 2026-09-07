# 0003 - Model terrain as a rolling sample stream

- **Status:** Accepted
- **Date:** 2026-09-07
- **Supersedes:** The deterministic synthetic-curve detail in [0001](0001-product-framing.md)

## Decision

Model terrain as a rolling stream of normalized metric samples. Each sample carries a monotonic timestamp and a value in `0...1`. The prototype source emits an indefinite bounded random walk. Future CPU or memory sources will implement the same source boundary.

Map samples to fixed horizontal intervals and connect them with straight line segments. Build the visible curve and collision edge from the same mapped points.

Advance the viewport continuously with time. The viewport follows the live data window, not the car, and trails the newest sample by a short delay. Prefilled and retained samples provide collision terrain outside both horizontal screen edges. Remove old samples and their scene geometry beyond the far-left retention margin.

## Rationale

A rolling source matches how genuine CPU and memory measurements will arrive. Normalized values keep metric acquisition independent from display scaling and physics. Piecewise-linear geometry preserves sample values and makes discrepancies between drawing and collision easy to inspect.

A delayed viewport uses already-collected values to provide terrain beyond the right screen edge. Offscreen margins let the car cross a visible edge without immediately losing collision support. Bounded pruning prevents an indefinite stream from causing indefinite memory growth.

## Consequences

- The displayed data is intentionally a short time behind the newest collected sample.
- The curve continues for the lifetime of the process but retained history remains finite.
- The prototype is random rather than reproducible across launches.
- Sample cadence, viewport delay, point spacing, scaling, and retention distances are implementation tuning values.
- Telemetry sources do not own terrain layout, drawing, or collision construction.
