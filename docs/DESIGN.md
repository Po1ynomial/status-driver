# Design

## Application structure

The application uses a native SwiftUI split view with one embedded SpriteKit graph. It remains a Swift Package Manager executable launched with `swift run`.

SwiftUI owns the window, sidebar, selected resource, telemetry session, detail labels, statistics, composition bar, and hardware metadata. SpriteKit owns only the selected main graph, terrain collision, keyboard input, and optional vehicle.

The application declares a macOS 26.0 deployment minimum and builds against the macOS 27.0 SDK with the Xcode 27 toolchain on the owner's macOS 27.0 machine. It may use convenient current APIs and makes no compatibility claim beyond that minimum.

## Performance layout

The Windows Task Manager Performance page is the structural reference. Status Driver opens directly into the Performance view because no other section has implemented content.

The native macOS sidebar contains only discovered and implemented resources in this order:

- CPU with a blue 60-second sparkline and current utilization.
- Memory with a violet 60-second sparkline and used, total, and percentage summary.
- Whole physical disks with green Activity sparklines.
- Physical Network interfaces with warm adaptive-throughput sparklines.
- GPU with a cyan-blue Device Utilization sparkline when the required property exists.

CPU is selected by default. Clicking a row changes the selected resource. There are no number-key resource shortcuts or unsupported placeholder rows.

The detail pane has the selected resource title, a hardware summary aligned at the upper-right, one large graph, and Task Manager-style statistics below. Memory adds a composition bar between its graph and statistics.

Use a unified macOS title bar, native sidebar material and selection, SF typography, monospaced changing values, separator-derived graph borders and grid, and automatic light and dark appearance. CPU is blue, Memory is violet, and the car remains orange.

The sidebar starts around 220 points wide, resizes provisionally between 190 and 280 points, and supports standard macOS collapse behavior. The default window remains about `1200 x 700` with a provisional minimum around `900 x 600`.

## Telemetry session

An application-owned session collects CPU and memory concurrently every 150 ms using a `ContinuousClock` task. All telemetry producers share one clock origin so their timestamps remain comparable. Collection continues while SpriteKit rendering is throttled or occluded and cancels when the session ends. Missed timer deadlines do not generate backfill readings.

Every resource maintains independent calculation, availability, filtering, and history. A read or discovery failure in one resource does not affect another.

Keep 150 ms CPU and Memory readings for current values and detail data, but resample their graph histories into one-second buckets. Each closed bucket appends one immutable point containing the arithmetic mean of its filtered readings. Open-bucket values are never exposed to sparklines, drawing, or collision.

Disk and GPU readings already arrive as filtered one-second samples. Commit each of those readings directly instead of passing it through another one-second bucket, which would add a full sample of latency. Neither history path generates empty catch-up points after suspension or sampling gaps.

Default launch uses genuine telemetry. Passing `--synthetic` creates the fixed deterministic synthetic resource set and visibly marks the data as synthetic. Runtime failures never change source mode.

Synthetic mode exposes deterministic CPU, Memory, Disk 0, Wi-Fi, and GPU resources. Each resource uses its own stable seed and emits detail values coherent with its primary graph.

## Dynamic resource lifecycle

Use a general resource identity with fixed CPU and Memory cases, IOKit registry ID plus whole BSD disk name for Disk, BSD interface name for Network, and IOKit registry ID for GPU.

Discover all resources immediately. Reconcile disks and physical interfaces every five seconds. Retry GPU discovery every five seconds only while missing or unavailable. Preserve histories, colors, selection, and metadata by stable identity.

A selected removed resource remains visible as unavailable until another resource is selected. An unselected removed disk disappears. A known physical interface remains listed as `Disconnected`. Newly attached resources enter the accepted sidebar order.

Resource descriptors include graph timing class, color role, detail type, availability, and easter-egg utility policy.

## Main graph and terrain

The selected graph displays a 60-second span across its current width with a fixed one-second commit horizon. Its left label says `61 seconds`; its right label says `1 second`. Historical terrain has about one immutable point per second. Current percentages still update at 150 ms and are intentionally newer than the committed graph.

Move the viewport with source time minus one second. A CPU or Memory bucket therefore finalizes offscreen right before any of its geometry enters view, while a committed Disk or GPU sample spends one second offscreen before entering. Never move the visible edge past the selected resource's latest committed timestamp. This cap absorbs normal sampling latency without drawing fabricated terrain. Keep real history beyond both visible edges when available, then add a hidden flat collision extension after the newest finalized point. The extension exists only to support the vehicle before boundary reset and is never drawn onscreen.

For physical resources, the selected history produces line, fill, and collision terrain from the same mapped points. CPU uses blue, Memory violet, Disk green, and GPU cyan-blue. The SpriteKit stroke retains butt caps and bevel joins because round tessellation produced detached fragments on long, nearly collinear paths.

Sidebar sparklines consume the same resampled histories through lightweight SwiftUI drawing. They have no collision or vehicle nodes.

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

## Disk performance

Discover whole physical media and read cumulative IOBlockStorageDriver statistics for read/write bytes, operations, total service time, and errors.

Calculate the fixed-scale physical terrain:

```text
service time = delta(total read time) + delta(total write time)
activity = clamp(service time / wall-clock interval, 0, 1)
```

Counter decreases cause rebaselining. Zero deltas produce available zero activity. Apply 0.75-second filtering and the immutable one-second terrain history.

The detail page has model, physical capacity, SSD/removable type, root-system-disk status, Activity, average response time, read/write rates, operation rates, and nonzero error deltas. It omits formatted capacity and page-file status.

Add a smaller nonphysical current-time transfer graph with separate read and write lines. It uses this adaptive ceiling ladder:

```text
1 MB/s, 10 MB/s, 100 MB/s, 500 MB/s, 1 GB/s, 2 GB/s, 5 GB/s, 10 GB/s
```

Raise immediately above 90 percent and lower after 30 seconds with both rates below 20 percent.

## Network performance

Discover physical hardware ports and map them to BSD interfaces. Include physical Wi-Fi and Ethernet. Exclude loopback, tunnel, bridge, AWDL, and system-only interfaces.

Read cumulative 64-bit byte, packet, error, and drop counters once per second. Counter decreases cause rebaselining. Derive send, receive, combined throughput, packet rates, and error/drop deltas.

The main Network graph is nonphysical SwiftUI content. It plots combined throughput through current time and normalizes against:

```text
100 KB/s, 1 MB/s, 10 MB/s, 100 MB/s, 1 GB/s, 10 GB/s
```

Start at 1 MB/s. Raise immediately above 90 percent and lower after 30 seconds below 20 percent. Adaptive rescaling may redraw visible Network history because it has no collision.

Show hardware-port name, BSD name, state, adaptive ceiling, send/receive/combined rates, packet rates, nonzero errors/drops, trustworthy link speed, and IP addresses. Omit SSID, signal, channel, PHY mode, and MAC address.

## GPU performance

Discover an IOKit graphics service only when its `PerformanceStatistics` dictionary contains `Device Utilization %`. Treat the key names as an experimental current-Mac dependency.

Use normalized Device Utilization as fixed-scale physical terrain with 0.75-second filtering and immutable one-second history. Show Renderer and Tiler utilization and in-use system memory when present. Show Metal and unified-memory metadata.

Omit GPU memory graphs or capacity ratios, frequency, temperature, power, DirectX data, PCI location, driver date, and Windows driver version. Hide an undiscoverable GPU. Retry a failed or missing source every five seconds.

## Adaptive graph scale

Nonphysical Network and Disk transfer graphs use discrete ceilings with shared hysteresis:

- Raise immediately when the current maximum exceeds 90 percent.
- Lower one ladder step only after 30 seconds continuously below 20 percent.
- Preserve scale state by stable resource identity.

Scale changes may redraw nonphysical history. They never alter committed physical terrain.

## Refresh tiers

- CPU, Memory, and raw VM fields update every 150 ms.
- Disk, Network, and GPU sample independently every one second.
- CPU and Memory graph histories commit immutable one-second averages. Disk and GPU commit their already-filtered one-second readings directly. Network and Disk transfer graphs update through current time.
- Disk and Network discovery runs every five seconds. GPU retries every five seconds only while absent or unavailable.
- Processes, best-effort threads, and uptime update once per second.
- Resource hardware metadata loads on discovery and refreshes only when identity changes.

Slow or failed secondary data never blocks graph sampling and only blanks its own field.

## Terrain-specific easter eggs

The global easter-egg toggle is hidden and disabled on every launch. It persists across resource selection for the application session but is not written to disk. There is no visible help, hint, toolbar item, tooltip, or first-run message.

Pressing `C` toggles the global state from any selected resource. CPU and GPU map enabled state to Car, Memory to Boat, Disk to Tetromino, Wi-Fi and Ethernet to Packet, and Thunderbolt Network to None.

One window-level input router receives key-down, key-up, and repeat events regardless of the current first responder. It converts raw keys into semantic commands for the selected utility and consumes only commands that utility uses. Utility models do not depend on AppKit focus or key codes.

Car remains the current two-wheel physics vehicle on CPU and GPU. Its controls remain:

- `Right` or `D`: drive right.
- `Left` or `A`: brake rightward movement, then drive left.
- `R`: reset.

Memory uses a small Boat on its usage boundary. A damped vertical spring produces bounded bobbing after level changes, and local slope supplies limited pitch. `A`/Left and `D`/Right use the Car movement and braking model. `R` resets above graph center.

Disk uses the seven classic Tetromino shapes and colors. The active piece descends and responds to `A`/Left, `D`/Right, `S`/Down, and `W`/Up in discrete block-sized steps. Up rotates exactly 90 degrees. Contact with terrain or a settled piece converts the active piece to a dynamic rigid body and spawns the next piece. `R` releases it immediately and spawns another. There is no grid, row clearing, score, or loss state.

Wi-Fi and Ethernet use a winged Packet against the adaptive throughput path. It flies at 30 percent graph width, uses gravity, and receives one upward impulse for each Space press. The graph top is a soft ceiling. Spawn height is the higher of 65 percent graph height or one packet-height above the current path. Swept collision catches narrow spikes. A collision attaches the inert packet to the struck sample until history carries it off the left edge, then it respawns. `R` resets it immediately.

Packet drawing, collision, and stuck attachment use the same samples and adaptive scale as the visible Network path. It has no SpriteKit terrain body. Thunderbolt Network has no utility until observed under useful traffic.

Disabling `C`, leaving a resource, or changing graph geometry removes the active utility and all transient bodies. Returning while global state remains enabled starts that resource's utility fresh. Fully offscreen Tetrominos are culled. Car and Boat use graph-boundary reset rather than application-window bounds.

## Inspection and checks

`swift run StatusDriverModelTests` covers telemetry calculations, counter rollover and reset, adaptive hysteresis, discovery reconciliation, interface filtering, stable identity/color, hot-plug rules, independent failure, synthetic coherence, timing classes, committed-sample edge coverage, easter-egg dispatch, immutable histories, scheduling, cancellation, and live system reads.

Manual inspection covers every resource page, colors, scale changes, hot-plug behavior where practical, both appearances, physical terrain, Disk/GPU right-edge continuity, nonphysical Network behavior, global easter-egg persistence, resize behavior, and bounded retention.
