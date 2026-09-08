# Task Manager Performance layout reference

## Question

Which information hierarchy should Status Driver use for its first full activity-monitor interface?

## Source

The owner supplied two screenshots during the interface grill:

- `/tmp/task-manager/cpu.jpg`
- `/tmp/task-manager/memory.jpg`

The files were temporary and expired before repository handback. They were inspected directly during the decision process.

## Observed structure

Both screenshots show the Windows Task Manager Performance page with:

- Application menus and section tabs across the top.
- A left resource list containing a bordered sparkline, resource name, and current summary for each item.
- CPU, Memory, Disk, Ethernet, Wi-Fi, and GPU resource rows.
- One selected row controlling the larger right detail pane.
- A large selected-resource title and hardware summary above the main graph.
- A 60-second graph with the oldest time at left and `0` at right.
- Detailed values arranged below the graph.

The CPU screenshot shows chip name, utilization, speed, process/thread/handle counts, uptime, base speed, sockets, cores, logical processors, virtualization, and L1 through L3 caches.

The Memory screenshot shows installed and usable memory, a large usage graph, a composition bar, in-use and compressed memory, available memory, committed memory, cache, paged and non-paged pools, speed, slots, form factor, and hardware-reserved memory.

## Adopted interpretation

Status Driver adopts the resource-sidebar, selected-detail, main-graph, and lower-statistics hierarchy. It omits the outer navigation because only Performance exists. It also omits unimplemented resource rows.

Windows-specific chrome and fields without honest macOS equivalents are not copied. The app uses native macOS split-view behavior, typography, appearance, and controls. CPU and Memory details are mapped in decision 0012.

## Confidence and limitations

Confidence is high for the observed hierarchy because both screenshots were inspected directly. The images represent an older Task Manager visual design rather than the latest Windows 11 shell, but the accepted rule concerns the Performance layout rather than pixel-level reproduction.
