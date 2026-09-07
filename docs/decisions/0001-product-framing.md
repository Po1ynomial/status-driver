# 0001 — Frame the product as an interactive activity monitor

- **Status:** Accepted; synthetic-source detail superseded by [0003](0003-rolling-terrain-model.md)
- **Date:** 2026-09-07

## Decision

Build a standalone macOS activity-monitor application that eventually renders genuine operating-system telemetry. Its statistical curves can also serve as physical terrain for an arrow-key-controlled car. The monitor remains the primary product, and the car is a surprising feature rather than a game objective.

The first milestone is an objective-free core prototype using one synthetic curve. Activity-monitor UI design and genuine telemetry are separate later slices.

The original deterministic-source detail is superseded by [0003](0003-rolling-terrain-model.md), which chooses a bounded random sample stream.

## Rationale

A standalone application controls both exact curve geometry and vehicle collision data, unlike an overlay that would need to infer terrain from another application's pixels. Starting with deterministic synthetic data isolates whether the distinctive interaction is understandable and enjoyable. Separating UI design prevents monitor chrome from obscuring the first physics experiment.

## Consequences

- No scoring, timer, fuel, win state, or game HUD in the initial direction.
- The first prototype may look deliberately minimal.
- Monitor information hierarchy requires a future grill slice.
- Telemetry selection and acquisition require later research and decisions.
- The synthetic source should be replaceable without redesigning terrain interaction.
