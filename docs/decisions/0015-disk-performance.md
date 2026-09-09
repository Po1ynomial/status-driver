# 0015 - Use service-time activity for Disk terrain

- **Status:** Accepted
- **Date:** 2026-09-09

## Decision

Discover each whole physical disk through IOKit and read cumulative IOBlockStorageDriver statistics for read/write bytes, operations, total service time, and errors.

Calculate Disk terrain as a best-effort activity estimate:

```text
service time = delta(total read time) + delta(total write time)
activity = clamp(service time / wall-clock interval, 0, 1)
```

Counter decreases indicate driver or device reset and cause rebaselining without a sample. Zero deltas remain available at zero percent. Summed service time can exceed wall time under parallel operations and clamps at 100 percent. Apply the existing 0.75-second filter and immutable one-second physical history.

The Disk detail page shows:

- Model and physical capacity.
- SSD or removable classification when discoverable.
- Root-system-disk status.
- Current Activity.
- Average response time for operations in the interval.
- Read and write bytes per second.
- Read and write operations per second.
- Read or write error deltas only when nonzero.

Add a smaller nonphysical Disk transfer graph below the Activity terrain. Plot read and write separately. It ends at current time and uses this adaptive ceiling ladder:

```text
1 MB/s, 10 MB/s, 100 MB/s, 500 MB/s, 1 GB/s, 2 GB/s, 5 GB/s, 10 GB/s
```

Raise the ceiling immediately when either direction exceeds 90 percent. Lower it only after 30 seconds with both rates below 20 percent. Scale changes may redraw this nonphysical graph. Disk sidebar sparklines show Activity rather than transfer rate.

Do not display formatted capacity or page-file status. APFS shared containers do not map cleanly to one formatted physical capacity, and macOS swap is not a useful per-disk property.

## Rationale

macOS does not expose the exact Windows Active Time counter, but public IOKit storage statistics provide cumulative service time and the rate/detail counters needed for a coherent page. Service time yields a naturally bounded terrain estimate without inventing a throughput capacity.

The supplied Task Manager reference uses a physical Active Time graph and a second nonphysical transfer graph. Keeping throughput separate preserves physical-terrain truth while allowing useful adaptive scaling.

## Consequences

- Disk Activity is documented as an estimate rather than Windows parity.
- Multiple physical disks produce separate rows and histories.
- IOKit counter rollover, reset, overflow, and parallel-time clamping need automated tests.
- The synthetic Disk source must generate coherent activity, transfer, operation, and response values.
