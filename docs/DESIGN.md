# Design

## Application structure

The application uses a native SwiftUI split view with one embedded SpriteKit graph. It remains a Swift Package Manager executable launched with `swift run`.

SwiftUI owns the window, sidebar, selected resource, telemetry session, detail labels, statistics, composition bar, and hardware metadata. SpriteKit owns only the selected main graph, terrain collision, keyboard input, and optional vehicle.

The application targets the owner's current macOS 26.2 machine. It may use convenient current APIs and makes no backward-compatibility claim.

## Performance layout

The Windows Task Manager Performance page is the structural reference. Status Driver opens directly into the Performance view because no other section has implemented content.

The native macOS sidebar contains two rows:

- CPU with a blue 60-second sparkline and current utilization.
- Memory with a violet 60-second sparkline and used, total, and percentage summary.

CPU is selected by default. Clicking a row or pressing `1` or `2` changes the selected resource and terrain. Do not add placeholder rows for unimplemented resources.

The detail pane has the selected resource title, a hardware summary aligned at the upper-right, one large graph, and Task Manager-style statistics below. Memory adds a composition bar between its graph and statistics.

Use a unified macOS title bar, native sidebar material and selection, SF typography, monospaced changing values, separator-derived graph borders and grid, and automatic light and dark appearance. CPU is blue, Memory is violet, and the car remains orange.

The sidebar starts around 220 points wide, resizes provisionally between 190 and 280 points, and supports standard macOS collapse behavior. The default window remains about `1200 x 700` with a provisional minimum around `900 x 600`.

## Telemetry session

An application-owned session collects CPU and memory concurrently every 150 ms using a `ContinuousClock` task. Collection continues while SpriteKit rendering is throttled or occluded and cancels when the session ends. Missed timer deadlines do not generate backfill readings.

CPU and memory each maintain independent calculation, availability, 0.75-second exponential moving average, and 60-second history. A read failure in one metric does not affect the other.

Default launch uses genuine telemetry. Passing `--synthetic` creates two independent random channels and visibly marks the data as synthetic. Runtime failures never change source mode.

## Main graph and terrain

The selected graph displays 60 seconds across its current width. Its left label says `60 seconds`; its right label says `0`. The rightmost visible value is the newest reading, so the graph and current percentage describe the same time.

Remove the previous visible live-edge delay. Keep real history beyond the left edge. Add a hidden flat collision extension beyond the visible right edge at the latest selected value. The extension exists only to support the vehicle before boundary reset and is never drawn onscreen.

The selected history produces the line, fill, and collision terrain from the same mapped points. CPU uses blue and Memory uses violet. The SpriteKit stroke retains butt caps and bevel joins because round tessellation produced detached fragments on long, nearly collinear paths.

Sidebar sparklines consume the same histories through lightweight SwiftUI drawing. They have no collision or vehicle nodes.

## CPU detail

CPU utilization remains aggregate non-idle Mach tick deltas over all logical CPUs. Successful zero-delta snapshots reuse the last valid value. Actual read failures preserve the stale value with unavailable status.

Load this hardware metadata once:

- Chip name.
- Package count.
- Physical and logical processor counts.
- Performance and efficiency core counts when performance levels exist.
- Virtualization support from `kern.hv_support`.
- Per-performance-level L1 instruction, L1 data, and L2 cache sizes.
- L3 only when exposed.

Refresh process count, best-effort aggregate thread count, and uptime once per second. Process enumeration uses public libproc data. A missing secondary value displays an em dash without changing CPU terrain availability.

Do not display current speed, base speed, handles, or cache levels the system does not expose.

## Memory detail

Memory retains the accepted calculation:

```text
app pages = max(0, internal pages - purgeable pages)
used pages = app pages + wired pages + compressor pages
memory value = used pages / physical pages
```

Raw VM details update with each 150 ms memory snapshot and provide:

- Installed physical memory.
- In use from the accepted estimate.
- Available as installed minus in use.
- App memory.
- Wired memory.
- Compressed memory.
- File cache from file-backed pages.
- Unified-memory type on Apple silicon.

The composition bar partitions physical memory into app, wired, compressed, and available remainder. File cache is a separate value because it belongs within reclaimable available memory.

Do not display committed memory, paged pool, non-paged pool, speed, slots, hardware reserved, memory pressure, or swap in this milestone.

## Refresh tiers

- CPU, Memory, raw VM fields, main graph, and sparklines update every 150 ms.
- Processes, best-effort threads, and uptime update once per second.
- Hardware metadata loads once per application session.

Slow or failed secondary data never blocks graph sampling and only blanks its own field.

## Vehicle easter egg

The car is hidden by default on every launch. There is no visible help, hint, toolbar item, tooltip, or first-run message for driving.

Pressing `C` creates the car above the selected terrain at graph center. Pressing `C` again removes its chassis, wheels, joints, and physics state. Driving and reset input have no effect while it is absent. Showing it after a selection change uses the current terrain.

Existing hidden controls remain:

- `Right` or `D`: drive right.
- `Left` or `A`: brake rightward movement, then drive left.
- `R`: reset.
- `1`: select CPU.
- `2`: select Memory.
- `C`: toggle the car.

Selection and graph-geometry changes reset a visible car. A hidden car remains hidden. Automatic offscreen reset uses the graph rectangle, not the application window. Clicking the graph restores keyboard focus after sidebar interaction.

## Inspection and checks

`swift run StatusDriverModelTests` covers telemetry calculations, hardware and secondary detail parsing, partial failures, independent histories, 60-second chart mapping, selection, hidden collision extension, vehicle visibility state, scheduling, cancellation, and live system reads.

Manual inspection covers CPU and Memory pages, sidebar sparklines and collapse, both appearances, current-time graph labels, detail values, Memory composition, resize behavior, selection, telemetry failure isolation, and the hidden car lifecycle and controls.
