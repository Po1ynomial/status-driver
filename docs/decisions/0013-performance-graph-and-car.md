# 0013 - Make the car a hidden graph easter egg

- **Status:** Accepted
- **Date:** 2026-09-08

## Decision

Make the selected main graph the only SpriteKit and physics area. SwiftUI owns the sidebar, header, labels, statistics, and Memory composition bar. Sidebar sparklines use the same histories without physics.

The main graph displays 60 seconds across its current width and ends at the newest reading. Label the left edge `60 seconds` and the right edge `0`. Remove the visible 2.75-second delay.

Retain real history beyond the left edge. Add a hidden flat collision extension beyond the live right edge using the newest selected value. Do not draw that fabricated extension onscreen.

Hide the car on every launch. `C` creates it above selected terrain at graph center or removes its bodies and joints. No interface text, toolbar item, popover, or tooltip reveals the car or its controls. Existing driving, reset, and metric shortcuts remain documented only in repository artifacts and source.

Selection and geometry-changing resize reset a visible car above the new terrain. A hidden car remains hidden. Automatic boundary reset uses the graph rectangle rather than the application window.

## Rationale

Task Manager graphs end at the present. The previous display delay made the right-edge `0` label and current percentage disagree. A hidden offscreen extension preserves collision safety without drawing invented data.

Restricting SpriteKit to the graph keeps physics out of monitor controls and statistics. Hiding the car preserves the monitor as the obvious product and makes driving a genuine easter egg.

## Consequences

- Horizontal terrain scale depends on graph width and changes during resize.
- Wheel speed needs retuning for the slower 60-second visual scroll.
- Resizing a visible graph rebuilds collision geometry and resets the car.
- `C` joins `A`/`D`, arrow keys, `R`, and `1`/`2` as an undisclosed binding.
- The app remains fully useful when no car exists.
