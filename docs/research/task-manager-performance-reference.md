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

The owner later supplied temporary Disk, Wi-Fi, and GPU screenshots. They were inspected during the additional-resource grill but are not copied into the repository because of licensing concerns.

The Disk screenshot shows one large Active Time graph, a smaller Disk Transfer Rate graph, current activity, average response time, read/write rates, capacity, formatted capacity, system-disk and page-file status, and storage type.

The Wi-Fi screenshot shows one adaptive Throughput graph, prominent Send and Receive values, adapter name, SSID, connection type, IP addresses, and signal strength.

The GPU screenshot shows an engine-utilization graph, shared GPU memory graph, utilization and memory values, driver metadata, DirectX version, and physical location.

## Adopted interpretation

Status Driver adopts the resource-sidebar, selected-detail, main-graph, and lower-statistics hierarchy. It omits the outer navigation because only Performance exists. It also omits unimplemented resource rows.

Windows-specific chrome and fields without honest macOS equivalents are not copied. The app uses native macOS split-view behavior, typography, appearance, and controls. CPU and Memory details are mapped in decision 0012. Disk, Network, and GPU adaptations are mapped in decisions 0015 through 0017.

## Confidence and limitations

Confidence is high for the observed hierarchy because both screenshots were inspected directly. The images represent an older Task Manager visual design rather than the latest Windows 11 shell, but the accepted rule concerns the Performance layout rather than pixel-level reproduction.
