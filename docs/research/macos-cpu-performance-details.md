# macOS CPU performance details

## Question

Which Task Manager CPU fields have public, unprivileged macOS equivalents on the target Apple-silicon Mac?

## Findings

Clear mappings exist for chip name, utilization, process count, best-effort thread count, uptime, packages, physical cores, logical processors, virtualization support, and cache topology.

No reliable public unprivileged mapping exists for current Apple-silicon CPU speed, one base speed, or Windows handle count.

## Local evidence

Current host values inspected during the interface grill:

```text
machdep.cpu.brand_string: Apple M4
hw.packages: 1
hw.physicalcpu: 10
hw.logicalcpu: 10
kern.hv_support: 1
hw.perflevel0.name: Performance
hw.perflevel0.physicalcpu: 4
hw.perflevel0.l1icachesize: 196608
hw.perflevel0.l1dcachesize: 131072
hw.perflevel0.l2cachesize: 16777216
hw.perflevel1.name: Efficiency
hw.perflevel1.physicalcpu: 6
hw.perflevel1.l1icachesize: 131072
hw.perflevel1.l1dcachesize: 65536
hw.perflevel1.l2cachesize: 4194304
```

`hw.cpufrequency`, `hw.cpufrequency_max`, and `hw.l3cachesize` returned no value on this Mac.

Public local headers provide:

- `proc_listallpids` in `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/libproc.h`.
- `proc_taskinfo.pti_threadnum` in `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/proc_info.h`.
- CPU and cache sysctl identifiers in `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/sysctl.h`.

A local `top -l 1 -n 0` sample reported 673 processes and 3,828 threads. This is comparison evidence only; implementation should use public libproc enumeration rather than parse `top`.

## Interpretation

- Label `hw.packages` as Packages rather than Windows Sockets.
- Label `kern.hv_support` as Virtualization Supported rather than Enabled.
- Show Apple-silicon caches per performance level because generic cache keys can represent only one level and would hide heterogeneous topology.
- Treat thread totals as best effort because processes can exit or reject inspection during enumeration.

## Confidence and limitations

Confidence is high for static hardware keys on the current host and moderate for a complete best-effort thread total. Values are specific to the owner's current Mac. Intel Macs expose a different topology and may expose nominal frequency and L3 values, but cross-Mac compatibility is not a project requirement.
