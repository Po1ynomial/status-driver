# Additional macOS Performance resources

## Question

Which Task Manager-style Disk, Network, and GPU metrics can Status Driver collect on the target Mac without root or permission prompts?

## Findings

### Disk

IOKit exposes whole physical media and IOBlockStorageDriver cumulative statistics. Local SDK constants document read/write bytes, operations, errors, latency time, and total service time. The target internal SSD exposes these values without privilege.

Observed target data included a whole `disk0` physical medium and cumulative read/write bytes, operation counts, and total read/write service nanoseconds. `iostat -Id disk0 1 3` produced live transfer deltas for comparison.

These counters support best-effort service-time activity, throughput, operation rate, response time, and errors. They do not provide the exact Windows Active Time definition.

### Network

`getifaddrs` and `if_data64` expose cumulative 64-bit received/sent bytes and packets, errors, drops, and optional baud rate. `SystemConfiguration` can map hardware-port names to BSD interfaces.

The target's active Wi-Fi interface is `en0`. It exposes byte and packet counters, IP addresses, and active state, but `ifconfig` reports `media: autoselect` without a useful link speed. This supports throughput but not an honest saturation percentage.

### GPU

The target Apple GPU IOKit registry exposes an undocumented `PerformanceStatistics` dictionary containing:

```text
Device Utilization %
Renderer Utilization %
Tiler Utilization %
In use system memory
Alloc system memory
```

`powermetrics --samplers gpu_power` requires superuser privileges. Public Metal counter sets describe command-buffer stages and do not provide whole-system GPU utilization.

The IOKit values are therefore usable only as a current-Mac best-effort source with graceful omission.

## Task Manager screenshot observations

The owner supplied temporary screenshots for Disk, Wi-Fi, and GPU during the grill. The files were inspected but are not copied into the repository because of licensing concerns.

Observed Disk hierarchy:

- Large Active Time graph.
- Smaller Disk Transfer Rate graph.
- Activity, average response time, read speed, and write speed.
- Capacity, formatted capacity, system-disk status, page-file status, and SSD type.

Observed Wi-Fi hierarchy:

- One adaptive Throughput graph.
- Prominent Send and Receive values.
- Adapter name, SSID, connection type, IP addresses, and signal strength.

Observed GPU hierarchy:

- Main engine-utilization graph.
- Shared GPU memory graph.
- Utilization and shared-memory values.
- Driver, DirectX, and physical-location metadata.

Status Driver adopts the graph and detail hierarchy but omits Windows-specific or permission-requiring fields under decisions 0015 through 0017.

## Provenance

- Local macOS 26.2 SDK headers under IOKit storage, network interface, SystemConfiguration, and Metal frameworks.
- Live `ioreg`, `iostat`, `netstat`, `ifconfig`, `networksetup`, and `powermetrics` probes on the owner's Apple M4 Mac.
- Owner-supplied temporary Task Manager screenshots inspected in-session.

## Confidence and limitations

Confidence is high for Disk and Network counter availability on the target and moderate for physical-resource discovery across hot-plug cases. GPU confidence is low beyond the current OS and hardware because its registry key names are not a documented API contract.

No external disk or Ethernet hot-plug was available during research. Implementation requires injected discovery fixtures and best-effort manual checks.
