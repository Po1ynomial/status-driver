# 0016 - Use adaptive nonphysical throughput for Network

- **Status:** Accepted
- **Date:** 2026-09-09

## Decision

Discover physical hardware ports and map them to BSD interface names. Include physical Wi-Fi and Ethernet interfaces. Exclude loopback, tunnels, bridges, AWDL, and other virtual or system interfaces by default.

Read cumulative 64-bit interface byte, packet, error, and drop counters. Derive one-second send, receive, combined throughput, packet rates, and error/drop deltas. Counter decreases cause rebaselining.

Use combined send plus receive bytes per second as the main graph. Normalize it against an adaptive ceiling chosen from:

```text
100 KB/s, 1 MB/s, 10 MB/s, 100 MB/s, 1 GB/s, 10 GB/s
```

Start at 1 MB/s. Raise immediately above 90 percent. Lower only after 30 seconds below 20 percent. Show the current ceiling at the graph's upper-right.

Network is a selectable Performance page but not physical terrain. Its current-time adaptive main graph is SwiftUI, ends at `0`, and may redraw visible history after a scale change. It has no SpriteKit collision, right extension, car, or other easter-egg utility in this milestone.

The detail page shows hardware-port name, BSD interface, connection state, adaptive ceiling, send, receive, combined throughput, send/receive packet rates, error and drop deltas when nonzero, trustworthy nonzero link speed, and current IPv4/IPv6 addresses. The sidebar emphasizes `S` and `R` rates.

Do not request Wi-Fi permission or display SSID, signal strength, channel, PHY mode, or MAC address.

## Rationale

Public interface counters provide honest rates, but Wi-Fi on the target Mac does not expose a useful baud rate. A claimed utilization percentage would therefore invent a capacity. Task Manager uses an adaptive throughput graph, which fits a nonphysical monitor page.

Adaptive rescaling contradicts immutable terrain. Making Network explicitly nonphysical resolves that conflict and leaves its future easter egg unconstrained.

## Consequences

- Network graph timing and rendering differ intentionally from physical resources.
- Disconnected physical interfaces remain visible but unavailable.
- Interface colors derive stably from hardware-port type and identity.
- A later grill will choose a Network easter-egg utility.
