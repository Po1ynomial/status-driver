# 0004 - Use a two-wheel keyboard-controlled car

- **Status:** Accepted
- **Date:** 2026-09-07

## Decision

Represent the car as a physical chassis with two physical wheels connected by pin joints. Wheel torque moves the car along the sampled terrain. Chassis torque controls rotation.

Use this complete initial control mapping:

- `Up` or `W`: accelerate forward.
- `Down` or `S`: brake, then reverse.
- `Left` or `A`: rotate counterclockwise.
- `Right` or `D`: rotate clockwise.
- `R`: reset.

Reset places the car upright above the terrain at the horizontal center of the current window and clears its linear and angular velocity. Trigger the same reset automatically after the full car body leaves any viewport edge.

## Rationale

Separate wheels create traction and terrain response that a single sliding body would not. Rotation controls make slopes and airborne movement controllable without adding a game system. One shared reset behavior keeps manual recovery and offscreen handling consistent.

The viewport remains tied to incoming data, so the car is free to move within and beyond the visible window. It does not stay centered.

## Consequences

- Physics constants and joint tuning remain implementation details.
- Terrain must remain present outside visible horizontal edges until automatic reset occurs.
- The first milestone has no other keys, touch input, controller support, or configurable bindings.
- Reset is recovery behavior, not a penalty or game objective.
