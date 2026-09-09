# 0013 - Make the car a hidden graph easter egg

- **Status:** Accepted; easter-egg state and resource shortcuts superseded by [0018](0018-resource-easter-eggs.md) and [0014](0014-dynamic-performance-resources.md)
- **Date:** 2026-09-08

## Decision

Make the selected main graph the only SpriteKit and physics area. SwiftUI owns the sidebar, header, labels, statistics, and Memory composition bar. Sidebar sparklines use the same histories without physics.

The main graph displays a 60-second span across its current width with a fixed one-second commit horizon. Label the left edge `61 seconds` and the right edge `1 second`. This replaces the previous 2.75-second delay while reserving enough time to finalize immutable terrain.

Collect telemetry at 150 ms but build chart and terrain history from one-second buckets. Finalize each bucket as the arithmetic mean of its filtered readings, append it once, and never modify an exposed point. Do not expose open-bucket readings to sidebar sparklines, visible geometry, or collision. Sampling gaps finalize the previous bucket and begin a new one without creating catch-up points.

Retain real history beyond the left edge. Add a hidden flat collision extension beyond the live right edge using the newest selected value. Do not draw that fabricated extension onscreen.

Hide the car on every launch. `C` creates it above selected terrain at graph center or removes its bodies and joints. No interface text, toolbar item, popover, or tooltip reveals the car or its controls. Existing driving, reset, and metric shortcuts remain documented only in repository artifacts and source.

Selection and geometry-changing resize reset a visible car above the new terrain. A hidden car remains hidden. Automatic boundary reset uses the graph rectangle rather than the application window.

## Rationale

The one-second commit horizon is required because a provisional right-edge point was visibly replaced by its average after entering the graph. In a deterministic example, the point at 0.90 seconds changed from 0.8000 to 0.4667 only 2.31 points left of the visible edge. Delaying committed terrain by one second ensures a bucket finalizes offscreen before it can enter view. Current numeric values remain live at 150 ms.

Mapping every 150 ms reading into a 60-second graph produced about 400 visible segments. At 924 points wide, horizontal spacing fell from the prototype's 18 points to 2.31 points while vertical sample changes stayed constant, amplifying local slope by about 7.79 times. One-second chart points restore roughly 15.4 points of horizontal spacing and reduce historical direction changes to about 60 without slowing current telemetry.

Restricting SpriteKit to the graph keeps physics out of monitor controls and statistics. Hiding the car preserves the monitor as the obvious product and makes driving a genuine easter egg.

## Consequences

- Horizontal terrain scale depends on graph width and changes during resize.
- Graph history is a one-second average of filtered telemetry rather than every collected reading.
- Current numeric values still update at 150 ms, while graph terrain is fixed one second behind.
- Wheel speed needs retuning for the slower 60-second visual scroll.
- Resizing a visible graph rebuilds collision geometry and resets the car.
- `C` joins `A`/`D`, arrow keys, `R`, and `1`/`2` as an undisclosed binding.
- The app remains fully useful when no car exists.
