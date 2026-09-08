# 0012 - Map performance details to honest macOS data

- **Status:** Accepted
- **Date:** 2026-09-08

## Decision

Follow Task Manager's selected-resource detail hierarchy but show only fields with a clear or explicitly adapted public macOS meaning.

The CPU page shows:

- Chip name.
- Current aggregate utilization.
- Process count.
- Best-effort thread count.
- Uptime.
- Packages, labeled instead of Windows sockets.
- Physical cores with performance and efficiency split when available.
- Logical processors.
- Virtualization support, not firmware-enabled state.
- Per-performance-level L1 instruction, L1 data, and L2 cache values when available.
- L3 only when the system exposes it.

Omit current speed, base speed, handles, and unavailable cache levels. A reliable unprivileged current-frequency API is not available on Apple silicon. Windows handles have no honest single macOS equivalent.

The Memory page shows:

- Installed physical memory.
- Current reclaimability-aware in-use value.
- Available remainder.
- App memory.
- Wired memory.
- Compressed memory.
- File cache from file-backed pages.
- Unified-memory type on Apple silicon.
- A composition bar segmented into app, wired, compressed, and available remainder.

File cache is displayed separately because it is part of reclaimable available memory. Omit committed memory, paged and non-paged pools, memory speed, slots, hardware reserved, pressure, and swap.

Refresh graph telemetry and raw VM details every 150 ms. Refresh processes, best-effort threads, and uptime once per second. Load hardware metadata once at startup. A secondary-field failure displays an em dash for that field and does not change terrain availability.

## Rationale

Task Manager's labels describe Windows scheduler, kernel, and memory concepts. Reusing labels without equivalent semantics would make the monitor look complete while reporting invented data.

macOS exposes clear process, core, uptime, VM, and hardware metadata. Apple silicon requires a different cache and core-topology presentation because performance and efficiency clusters have different values. Slow system enumeration should not block graph sampling or rendering.

## Consequences

- Thread count may slightly undercount protected or exiting processes and is treated as best effort.
- Apple silicon shows performance and efficiency core/cache topology rather than one generic cache hierarchy.
- No privileged `powermetrics` integration is added for frequency data.
- Memory remains a project-defined estimate rather than Activity Monitor parity.
- Pressure and swap remain candidates for later expansion.
