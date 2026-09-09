# 0014 - Discover and reconcile dynamic Performance resources

- **Status:** Accepted
- **Date:** 2026-09-09

## Decision

Extend the Performance sidebar in this order:

1. CPU.
2. Memory.
3. Whole physical disks.
4. Physical Network interfaces.
5. GPU when its utilization property exists.

Use stable resource identities:

- Fixed identities for CPU and Memory.
- IOKit registry entry ID plus whole-disk BSD name for Disk.
- BSD interface name for Network.
- IOKit registry entry ID for GPU.

Discover resources immediately. Re-run Disk and Network discovery every five seconds. Retry GPU discovery every five seconds only while it is unavailable or absent. Load resource hardware metadata on discovery and refresh it only when identity changes.

A selected removed resource remains visible as unavailable until another resource is selected. An unselected removed disk disappears. A known physical Network interface remains visible as `Disconnected`. New resources appear in accepted order.

Remove all number-key resource shortcuts. Every resource is selected by clicking its sidebar row. Preserve selection by stable identity through list refreshes.

Assign stable resource colors: CPU blue, Memory violet, Disk green, Wi-Fi orange, Ethernet muted brick red, other physical Network interfaces from a deterministic warm palette, and GPU cyan-blue.

CPU and Memory retain 150 ms sampling. Disk, Network, and GPU sample independently once per second. Resource discovery and one resource's failure never block another source or rendering.

## Rationale

Disk and interface membership can change while the app is running. Stable identity prevents discovery from discarding history or switching the selected page. Retaining a selected removed resource avoids an unexplained page change, while removing unselected dead disks prevents permanent clutter.

Dynamic number shortcuts would change meaning as resources appear or disappear. A partial keyboard model for CPU and Memory is worse than one consistent click-only rule.

One-second sampling matches immutable chart density and current rate calculations. Faster IOKit registry walks add cost without producing more physical terrain detail.

## Consequences

- The fixed CPU/Memory metric identity must become a general Performance resource model.
- Sidebar rows are data-driven but never show unsupported placeholders.
- Selection tests cover reconciliation, removal, and disconnected state.
- Existing `1` and `2` commands and key handling are removed.
- Hot-plug checks are best effort in manual testing because hardware may not be available.
