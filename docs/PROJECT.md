# Status Driver

## Goal

Build a standalone macOS activity monitor whose statistical curves also act as terrain for a keyboard-controlled car. The monitor is the primary product. Driving is an undisclosed easter egg rather than a game objective.

## Users

The initial audience is the project's owner. This is a personal, entertaining macOS project rather than a distributed product.

## Current milestone

Turn the CPU and Memory prototype into a recognizable activity-monitor interface. Follow the Windows Task Manager Performance layout and translate its controls, typography, appearance, and window behavior to native macOS conventions.

## In scope

- A native split view with CPU and Memory resource rows.
- Sixty-second sidebar sparklines and one selected detail graph.
- Task Manager-style CPU and Memory detail statistics that map honestly to public macOS data.
- Reclaimability-aware memory composition.
- CPU blue and Memory violet visual identities.
- Automatic light and dark appearance.
- A live graph ending at the newest reading with hidden offscreen collision support.
- A hidden-by-default car toggled with `C`.
- Existing terrain selection, driving, resize, and reset behavior.

## Out of scope for the current milestone

- Task Manager sections other than Performance.
- Placeholder rows for Disk, Network, GPU, processes, or other unimplemented resources.
- Current or baseline CPU speed and Windows handle counts.
- Windows committed memory, paged pool, non-paged pool, memory speed, slots, or hardware-reserved fields.
- Memory pressure, swap, per-core graphs, process lists, disk, or network telemetry.
- Visible driving help, control hints, game objectives, or HUD.
- Persisted telemetry history.
- Application bundling, signing, notarization, or distribution.

## Constraints

- The Windows Task Manager Performance page is the information-layout reference.
- Native macOS components and behavior take precedence over copying Windows chrome.
- The sidebar contains only implemented resources and can resize or collapse using macOS behavior.
- CPU and Memory retain independent telemetry, availability, smoothing, and history.
- The main graph and sidebar sparklines show the same truthful 60-second history.
- The visible graph ends at the newest reading. Fabricated flat terrain may exist only outside the visible right edge for collision safety.
- SpriteKit is limited to the main graph area.
- Secondary detail failures never mark terrain telemetry unavailable.
- The car remains absent until the user presses `C` and has no in-application documentation.
- The monitor remains useful with the car hidden.

## Success conditions

- The app opens directly into a native Performance split view with CPU selected.
- The sidebar shows only CPU and Memory, each with current value and 60-second sparkline.
- Clicks and `1`/`2` select the matching resource and main terrain.
- CPU details show chip name, utilization, processes, best-effort threads, uptime, packages, core topology, logical processors, virtualization support, and available cache topology.
- CPU omits speed, base speed, handles, and unavailable cache levels.
- Memory details show installed, in use, available, app, wired, compressed, file-cache, and unified-memory values plus a composition bar.
- Memory omits fields without honest macOS mappings.
- Main graph labels describe a 60-second history ending at `0` and remain consistent with the current value.
- CPU uses blue, Memory uses violet, and the interface supports native light and dark appearances.
- Fast telemetry remains at 150 ms, process/thread/uptime details refresh once per second, and hardware metadata loads once.
- The default window is about `1200 x 700`; a provisional minimum near `900 x 600` keeps the graph usable.
- The car is hidden on launch. `C` creates or removes it inside the graph without affecting telemetry.
- Selection and geometry-changing resize reset a visible car. A hidden car remains hidden.
- Automated checks cover detail calculations, partial metadata, secondary failure isolation, 60-second chart mapping, hidden collision support, and car visibility state.
- Manual checks cover both appearances, sidebar behavior, both detail pages, live timing, composition, selection, resizing, and all hidden car controls.

## Open questions

- Which system metric should follow memory, if any?
- Should memory pressure or swap appear in a later detail expansion?
- Does the provisional split-view sizing need adjustment after use?
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
