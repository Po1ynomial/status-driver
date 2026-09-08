# 0010 - Select terrain from a compact metric strip

- **Status:** Accepted; compact-strip presentation superseded by [0011](0011-performance-interface-structure.md)
- **Date:** 2026-09-07

## Decision

Show CPU and memory in one compact upper-left strip. Update both values continuously and mark the selected terrain with an orange indicator and stronger border.

[0011](0011-performance-interface-structure.md) moves these resources into a native sidebar. The selection, availability, history, switching, and synthetic-mode behavior below remains accepted.

Clicking an available item selects it. `1` selects CPU and `2` selects memory. CPU is the default selection.

Maintain an independent rolling history for each metric. Selection atomically replaces drawing and collision geometry with the chosen history, preserves viewport time, and resets the car upright above terrain at window center. Do not morph between histories.

An unavailable unselected metric cannot be selected. If the active metric becomes unavailable, keep it selected and extend flat terrain from its last valid value. Recover in place without resetting the car or switching automatically.

In `--synthetic` mode, create independent random CPU and memory channels. Keep the same selector behavior and add a persistent `SYNTHETIC` marker.

## Rationale

The strip exposes the first real monitor choice without requiring panels, settings, axes, or a finished information hierarchy. Keeping both histories warm makes switching immediate. An atomic replacement keeps every rendered shape physically truthful, while a car reset avoids embedding the vehicle in terrain at a different height.

Automatic source switching would override user intent and could replace terrain without input. Explicit selection is predictable.

Dual-channel synthetic mode exercises switching and physical extremes without manipulating real memory use. The synthetic marker prevents generated values from being mistaken for telemetry.

## Consequences

- Selection state belongs to the application layer and is shared by the strip and scene.
- Number keys `1` and `2` join the existing driving and reset controls.
- Switching terrain intentionally resets the vehicle but not timeline position.
- Both histories continue pruning while unselected.
- The milestone adds no other monitor layout or controls.
