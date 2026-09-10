# Status Driver

## Goal

Build a standalone macOS activity monitor whose statistical curves can also become surfaces for hidden resource-specific easter eggs. The monitor is the primary product. The current car is one undisclosed easter-egg utility rather than a game objective.

## Users

The initial audience is the project's owner. This is a personal, entertaining macOS project rather than a distributed product.

## Current milestone

Match each hidden easter-egg utility to the characteristic terrain of its resource while preserving the activity monitor as the primary product.

## In scope

- Car for CPU and GPU terrain.
- A damped-buoyancy Boat for Memory terrain.
- A free-physics Tetromino dropper for Disk terrain.
- A fixed-horizontal-position Packet flyer for Wi-Fi and Ethernet throughput.
- No utility for Thunderbolt Network until its graph behavior is observed.
- One session-wide hidden toggle with resource-specific controls.
- Window-level semantic input routing independent of view focus.
- Deterministic lifecycle cleanup, reset, collision, and bounded object retention.

## Out of scope for the current milestone

- Full Tetris rules, grid enforcement, row clearing, scoring, preview, hold, or loss state.
- Network terrain physics or immutable adaptive graph history.
- A Thunderbolt Network utility.
- Persistent easter-egg state, configurable shortcuts, or visible help.
- New Performance resources or telemetry fields.
- Process lists, persistence, packaging, signing, or outer application navigation.

## Constraints

- Resource order is CPU, Memory, whole physical disks, physical network interfaces, then GPU.
- Stable resource identity preserves history, color, selection, and details across discovery refreshes.
- CPU and Memory retain their 150 ms collection; new resources sample once per second.
- Resource discovery runs every five seconds without blocking sampling or rendering.
- Physical CPU, Memory, Disk Activity, and GPU graphs expose immutable one-second terrain from 61 to 1 seconds ago.
- Adaptive Network and Disk transfer graphs are nonphysical and may redraw current visible history through `0`.
- The global `C` toggle persists across resource selection for the session but starts off on each launch.
- Utility input works at the application-window level and does not depend on graph focus.
- Utilities never alter, smooth, decorate, or fabricate the statistical curves they use.
- Adaptive Network collision and attachment derive from the same current path as the visible graph.
- Hidden and offscreen physics objects remain bounded.
- No runtime failure silently changes resource, source mode, graph scale policy, or easter-egg state.
- The app uses public unprivileged APIs where documented; GPU registry properties are an explicit current-Mac best-effort exception.

## Success conditions

- Default launch immediately discovers available Disk, physical Network, and GPU resources, then reconciles Disk and Network every five seconds.
- Existing CPU and GPU Car behavior remains intact.
- Disk Activity uses clamped read-plus-write service-time deltas over wall time and zero activity remains available.
- Disk detail shows model, physical capacity, type, root-disk status, activity, response time, read/write speed, and operation rates.
- A nonphysical Disk transfer graph ends at now, plots read and write separately, and uses stable adaptive scale hysteresis.
- Network detail shows hardware port, BSD name, state, adaptive ceiling, send/receive/combined rates, packet rates, errors or drops when nonzero, addresses, and trustworthy link speed when present.
- Network terrain is absent; its main adaptive SwiftUI graph ends at now.
- GPU appears only when Device Utilization is discoverable, uses that fixed percentage for terrain, and shows Renderer, Tiler, Metal/unified-memory metadata, and in-use system memory when present.
- GPU failure keeps a discovered row unavailable and retries discovery without affecting other resources.
- Removed selected resources remain unavailable until another resource is chosen; removed unselected disks disappear; disconnected physical interfaces remain listed.
- Disk is green, Wi-Fi orange, Ethernet muted brick red, other physical interfaces use stable warm colors, and GPU is cyan-blue.
- Synthetic mode contains deterministic CPU, Memory, Disk 0, Wi-Fi, and GPU data with coherent details.
- Sidebar clicks are the only resource-selection method.
- Memory Boat follows the usage boundary with damped buoyancy, limited pitch, rover-style horizontal controls, and deterministic reset.
- Disk uses seven classic discretely controlled tetrominos that become dynamic on collision or `R`, pile physically, and clear on utility teardown.
- Wi-Fi and Ethernet use a winged Packet with Space impulse, soft ceiling, terrain-aware spawn, swept collision, stuck-sample scrolling, and immediate `R` reset.
- Thunderbolt interfaces map enabled state to None.
- Global easter-egg state starts disabled, survives resource changes, dispatches the accepted utility, and remains undisclosed.
- Automated checks cover semantic input, utility dispatch and cleanup, buoyancy bounds, tetromino stepping and conversion, packet collision and attachment, adaptive rescaling, and bounded retention.
- Manual checks cover every utility, controls under different focused views, resource switching, resize cleanup, graph boundaries, both appearances, and synthetic plus useful live terrain.

## Open questions

- Which utility, if any, fits Thunderbolt Network traffic after live observation?
- Which additional resource, if any, belongs after GPU?
- When, if ever, should the project add packaging and distribution?

## Accepted decisions

- [Frame the product as an interactive activity monitor](decisions/0001-product-framing.md)
- [Use native frameworks and source-run delivery](decisions/0002-prototype-platform-and-delivery.md)
- [Model terrain as a rolling sample stream](decisions/0003-rolling-terrain-model.md)
- [Use a small two-wheel horizontally controlled car](decisions/0004-driving-interaction.md)
- [Keep the prototype visually minimal and inspectable](decisions/0005-prototype-presentation-and-completion.md)
- [Use aggregate CPU utilization for genuine terrain](decisions/0006-aggregate-cpu-terrain.md)
- [Own telemetry outside the rendering loop](decisions/0007-telemetry-stream-lifecycle.md)
- [Identify telemetry without designing the full monitor](decisions/0008-telemetry-presentation-and-completion.md)
- [Estimate reclaimability-aware used memory](decisions/0009-memory-telemetry.md)
- [Select terrain from a compact metric strip](decisions/0010-metric-terrain-selection.md)
- [Use a Task Manager Performance structure with macOS controls](decisions/0011-performance-interface-structure.md)
- [Map performance details to honest macOS data](decisions/0012-performance-detail-mapping.md)
- [Make the car a hidden graph easter egg](decisions/0013-performance-graph-and-car.md)
- [Discover and reconcile dynamic Performance resources](decisions/0014-dynamic-performance-resources.md)
- [Use service-time activity for Disk terrain](decisions/0015-disk-performance.md)
- [Use adaptive nonphysical throughput for Network](decisions/0016-network-performance.md)
- [Use best-effort IOKit GPU utilization](decisions/0017-gpu-performance.md)
- [Dispatch one global easter-egg toggle by resource](decisions/0018-resource-easter-eggs.md)
- [Match easter eggs to resource terrain](decisions/0019-terrain-specific-easter-eggs.md)
