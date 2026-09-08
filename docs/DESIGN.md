# Design

## Application structure

The application uses a native SwiftUI shell with an embedded SpriteKit scene. It remains a Swift Package Manager executable launched with `swift run`.

SwiftUI owns the application lifecycle, telemetry session, source selection, compact metric selector, and selected metric. SpriteKit owns curve rendering, keyboard driving input, vehicle simulation, and terrain collision. SpriteKit consumes filtered metric readings but never calls Mach APIs or schedules telemetry collection.

The application targets the owner's current macOS 26.2 machine. It may use convenient current APIs and makes no backward-compatibility claim.

## Telemetry session

An application-owned session collects CPU and memory concurrently every 150 ms using a `ContinuousClock` task. Collection continues while SpriteKit rendering is throttled or occluded and cancels when the application session ends. Missed timer deadlines do not generate backfill readings.

CPU and memory each maintain independent acquisition state, availability, 0.75-second time-aware exponential moving average, and rolling history. A read failure in one metric does not affect the other.

Default launch uses genuine telemetry. Passing `--synthetic` creates two independent bounded random channels and marks the interface as synthetic. Runtime failures never change source mode.

## CPU calculation

Read cumulative user, system, idle, and nice ticks with `host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, ...)`.

For each pair of successful reads:

1. Compute wrapping deltas for all four counters.
2. Add user, system, and nice deltas as busy ticks.
3. Add busy and idle deltas as total ticks.
4. Divide busy by total and clamp to `0...1`.
5. If no ticks advanced, reuse the last filtered value. Keep it available after at least one valid utilization; startup remains unavailable until a valid utilization exists.

A value of `1.0` means all logical CPUs are busy. Status Driver's own work remains part of that total.

## Memory calculation

Read VM counters with `host_statistics64(mach_host_self(), HOST_VM_INFO64, ...)`. Read total physical bytes with `sysctlbyname("hw.memsize", ...)` and derive the physical page count from the host page size.

Calculate a reclaimability-aware used-memory estimate:

```text
app pages = max(0, internal pages - purgeable pages)
used pages = app pages + wired pages + compressor pages
memory value = used pages / physical pages
```

Clamp arithmetic and the final value to `0...1`. File-backed cache and purgeable pages remain available to the system and do not count as used. Swap is not physical RAM and does not enter the percentage.

This is a documented project metric, not a claim to reproduce Activity Monitor's private calculation exactly. Preserve raw VM fields in the internal reading so later monitor work can display a breakdown.

## Startup and failure behavior

Each metric starts with its first successful filtered value and prefills a flat retained history. No telemetry persists between launches.

After an actual source failure, the affected metric emits its last filtered value with unavailable status. Before any successful value, use `0.5` as a neutral fallback after a short grace period. Retry every interval.

An unavailable unselected metric remains visible but cannot be selected. If the selected metric fails, keep it selected and extend flat terrain with its stale value. Recovery resumes genuine terrain without resetting the car or selecting another metric.

## Rolling histories and terrain

CPU and memory have independent rolling sample buffers on one shared monotonic timeline. Both append and prune while either metric is selected.

The selected buffer maps to fixed horizontal intervals and the scene's configured vertical range. Adjacent samples form straight segments. Drawing and collision construction consume the same mapped points. The SpriteKit stroke uses butt caps and bevel joins because round tessellation produced detached fragments on long, nearly collinear CPU paths.

The viewport advances smoothly with session time and trails newest samples by a short fixed delay. It follows the live data window, not the car. Retention keeps terrain outside both horizontal edges and remains bounded.

Changing selection preserves viewport time and atomically replaces line, fill, and collision geometry from the new metric's existing history. The scene resets the car upright above terrain at window center. It does not morph between metrics.

## Vehicle

The car is a small chassis with two physical wheels connected by pin joints. Wheel torque moves it along terrain. Terrain contact and gravity determine chassis rotation.

Controls are:

- `Right` or `D`: drive toward the right.
- `Left` or `A`: brake rightward motion, then drive toward the left.
- `R`: reset.

`Up`, `Down`, `W`, and `S` remain unbound.

## Presentation and selection

The upper-left strip shows both current percentages:

```text
[ CPU 8% ] [ MEMORY 71% ]
```

The selected item has the orange indicator and stronger border. Clicking an available item selects it. `1` selects CPU and `2` selects memory. An unavailable item says `CPU unavailable` or `MEMORY unavailable`.

Synthetic mode adds a persistent `SYNTHETIC` marker while retaining the same two-item selector and shortcuts. This compact strip is the full GUI scope for the milestone.

## Inspection and checks

`swift run StatusDriverModelTests` covers CPU and memory calculations, arithmetic bounds, smoothing, failure isolation, source selection, startup, independent histories, selector rules, scheduling, cancellation, and live Mach reads.

Manual inspection covers both selector methods, atomic terrain replacement, car reset, unavailable behavior, synthetic labeling, driving on each metric, resizing, occlusion recovery, and bounded retention.
