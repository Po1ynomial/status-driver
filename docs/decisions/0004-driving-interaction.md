# 0004 - Use a small two-wheel horizontally controlled car

- **Status:** Accepted; amended after prototype inspection
- **Date:** 2026-09-07

## Decision

Represent the car as a physical chassis with two physical wheels connected by pin joints. Scale the vehicle to about 55 percent of its original prototype size so the terrain remains visually dominant. Wheel motors move the car, while slopes, gravity, and collisions determine chassis rotation.

Use this complete current control mapping:

- `Right` or `D`: drive toward the right.
- `Left` or `A`: brake rightward motion, then drive toward the left.
- `R`: reset.

Leave `Up`, `Down`, `W`, and `S` unbound. Add vertical or rotation controls later only if they have a matching arrow-key layout.

Reset removes the existing bodies and pin joints, then creates an upright vehicle above the terrain at the horizontal center of the current window. Trigger the same reset automatically after the full car body leaves any viewport edge.

## Rationale

Separate wheels create traction and terrain response that a single sliding body would not. The first implementation made the chassis too large relative to the terrain. Direct rotation on `A` and `D` also applied enough torque to spin, jump, and cross the terrain in ways that did not read as driving.

A smaller car restores the graph as the main visual element. Horizontal controls match the car's screen movement. Removing direct chassis torque lets the terrain and wheel contact produce rotation without a second, competing control model.

Recreating the vehicle during reset gives SpriteKit fresh bodies and joints. Moving an existing jointed assembly caused stale solver impulses after teleportation.

## Superseded direction

The initial mapping used `Up`/`W` for acceleration, `Down`/`S` for braking and reverse, and `Left`/`A` plus `Right`/`D` for direct chassis rotation. Prototype inspection rejected that mapping because the direct torque dominated the vehicle motion.

## Consequences

- Physics bodies, masses, and motor torque scale down with the vehicle.
- Precise collision detection is enabled for the smaller bodies.
- A flipped car has no airborne correction control and uses `R` for recovery.
- Terrain must remain present outside visible horizontal edges until automatic reset occurs.
- The viewport remains tied to incoming data rather than the car.
- No other keys, controller support, or configurable bindings belong to this milestone.
