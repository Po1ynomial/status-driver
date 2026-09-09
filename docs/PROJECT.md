# Status Driver

## Goal

Build a standalone macOS activity monitor whose statistical curves can also become surfaces for hidden resource-specific easter eggs. The monitor is the primary product. The current car is one undisclosed easter-egg utility rather than a game objective.

## Users

The initial audience is the project's owner. This is a personal, entertaining macOS project rather than a distributed product.

## Current milestone

Extend the Task Manager-style Performance interface with physical disks, physical network interfaces, and best-effort GPU telemetry. Preserve honest macOS semantics, stable resource identity, immutable physical terrain, and one global hidden easter-egg toggle.

## In scope

- Immediate and five-second discovery of whole physical disks and physical network interfaces.
- One-second independent sampling for Disk, Network, and GPU.
- Disk service-time activity terrain plus current adaptive transfer-rate graph.
- Adaptive combined-throughput Network graphs with per-interface detail.
- Best-effort experimental GPU utilization and detail from current IOKit registry properties.
- Dynamic sidebar rows with stable identity, ordering, colors, failure state, and hot-plug behavior.
- Deterministic synthetic Disk 0, Wi-Fi, and GPU resources.
- A session-wide hidden easter-egg toggle with per-resource utility dispatch.

## Out of scope for the current milestone

- Virtual, loopback, bridge, tunnel, AWDL, and other system-only Network rows.
- Wi-Fi SSID, signal, channel, or PHY mode and their permission requirements.
- GPU frequency, temperature, power, fixed memory capacity, or memory graph.
- Root helpers, `powermetrics`, shell-command parsing, or privileged acquisition.
- Disk formatted capacity and page-file fields.
- New easter-egg utilities for Network or other future resources.
- Number-key resource shortcuts, configurable shortcuts, or visible easter-egg help.
- Process lists, persistence, packaging, signing, or outer application navigation.

## Constraints

- Resource order is CPU, Memory, whole physical disks, physical network interfaces, then GPU.
- Stable resource identity preserves history, color, selection, and details across discovery refreshes.
- CPU and Memory retain their 150 ms collection; new resources sample once per second.
- Resource discovery runs every five seconds without blocking sampling or rendering.
- Physical CPU, Memory, Disk Activity, and GPU graphs expose immutable one-second terrain from 61 to 1 seconds ago.
- Adaptive Network and Disk transfer graphs are nonphysical and may redraw current visible history through `0`.
- Network has no easter-egg utility in this milestone.
- The global `C` toggle persists across resource selection for the session but starts off on each launch.
- No runtime failure silently changes resource, source mode, graph scale policy, or easter-egg state.
- The app uses public unprivileged APIs where documented; GPU registry properties are an explicit current-Mac best-effort exception.

## Success conditions

- Default launch immediately discovers available Disk, physical Network, and GPU resources, then reconciles Disk and Network every five seconds.
- CPU and Memory behavior remains unchanged except removal of `1` and `2` shortcuts.
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
- Global easter-egg state starts disabled, survives resource changes, maps CPU/Memory/Disk/GPU to Car and Network to None, and remains undisclosed.
- Automated checks cover counter arithmetic, rollover and reset, adaptive scaling, filtering, discovery reconciliation, interface filtering, stable identity and color, hot-plug rules, independent failures, synthetic coherence, graph timing, and easter-egg dispatch.
- Live checks compare Disk and Network values with system tools and confirm GPU utilization on the target M4.
- Manual checks cover all resource pages, colors, scale changes, hot-plug behavior where practical, physical terrain, global `C` behavior, graph boundaries, both appearances, and bounded retention.

## Open questions

- Which resource-specific easter egg should Network use later?
- Should external removable disks receive the car or a different utility?
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
