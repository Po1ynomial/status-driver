# 0011 - Use a Task Manager Performance structure with macOS controls

- **Status:** Accepted; two-resource list extended by [0014](0014-dynamic-performance-resources.md)
- **Date:** 2026-09-08

## Decision

Use the Windows Task Manager Performance page as the information-layout reference. Open directly into a native macOS split view without an outer section-navigation rail.

The sidebar contains only CPU and Memory. Each row has a 60-second sparkline, resource name, and current summary. CPU is selected by default. The selected resource controls one large detail graph and the statistics below it.

Use a native macOS unified title bar, sidebar material, selection behavior, divider, SF typography, monospaced changing values, and automatic light and dark appearance. The sidebar starts near 220 points, resizes provisionally between about 190 and 280 points, and supports standard macOS collapse behavior. The default window is about `1200 x 700` with a provisional minimum near `900 x 600`.

CPU uses blue and Memory uses violet across sparklines, main graphs, fills, and Memory composition. The car remains orange.

## Rationale

Task Manager already solves the central information hierarchy: compact resources on the left, one detailed performance history on the right, and selected-resource statistics below. Copying that structure avoids inventing a dashboard that weakens the terrain graph.

Windows menus, tabs, and window controls do not belong in a macOS application. Native controls preserve expected resizing, keyboard focus, appearance, and accessibility behavior.

Only Performance has implemented content. An outer navigation rail or unimplemented resource rows would be dead interface.

## Consequences

- CPU and Memory are the only sidebar rows in this milestone.
- New resources appear only after their telemetry and detail page exist.
- The current floating selector is removed.
- The sidebar and main graph use the same retained histories.
- Split-view bounds remain provisional and may change after human inspection.
- Full process, app-history, startup, users, details, and services sections remain out of scope.
