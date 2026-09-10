# 0018 - Dispatch one global easter-egg toggle by resource

- **Status:** Accepted; utility mapping superseded by [0019](0019-terrain-specific-easter-eggs.md)
- **Date:** 2026-09-09
- **Supersedes:** Resource-shortcut and selection-local visibility details in [0013](0013-performance-graph-and-car.md)

## Decision

Model easter-egg visibility as one application-session boolean. It starts disabled on every launch and is toggled by undisclosed `C`, regardless of selected resource.

Each resource maps enabled state to an easter-egg utility:

- CPU: Car.
- Memory: Car.
- Disk: Car.
- GPU: Car.
- Network: None for now.

Switching from a Car resource to Network removes the vehicle but leaves global enabled state true. Switching from Network back to CPU, Memory, Disk, or GPU recreates the car automatically. Pressing `C` on Network still changes global state even though nothing is visible. Switching resources while globally disabled never creates a utility.

The toggle persists across resource selection only for the current session. It is not written to disk. No UI text, control, tooltip, accessibility hint, or menu reveals the state or key.

Remove `1` and `2` metric shortcuts under [0014](0014-dynamic-performance-resources.md). Existing driving and reset keys remain effective only while the selected resource's current utility is Car.

## Rationale

Future resources may use different hidden utilities. Separating global intent from resource-specific implementation prevents each tab from inventing its own toggle state. Session persistence lets a discovered easter egg follow the user across compatible resources without making the car appear automatically on a future launch.

Network's adaptive graph cannot support immutable car terrain. Mapping it to None keeps the resource useful now and leaves a later easter egg open for design.

## Consequences

- Easter-egg policy belongs to the general resource descriptor.
- Selecting a resource reconciles the current utility against global state.
- Network needs no SpriteKit graph in this milestone.
- Later utility types can join the dispatch model without changing `C` semantics.
