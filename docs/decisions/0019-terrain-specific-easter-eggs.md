# 0019 - Match easter eggs to resource terrain

- **Status:** Accepted
- **Date:** 2026-09-10
- **Supersedes:** Utility mapping in [0018](0018-resource-easter-eggs.md) and graph-focus input details in [0013](0013-performance-graph-and-car.md)

## Decision

Choose each hidden utility from the characteristic shape and timing of its resource graph:

- CPU and GPU retain Car because their terrain is usually bumpy without being impassable.
- Memory uses Boat because its usage boundary is usually flat and changes level when applications allocate or release substantial memory.
- Disk uses Tetromino because its Activity terrain is usually near zero with occasional spikes.
- Wi-Fi and Ethernet, including USB Ethernet adapters, use Packet because throughput is adaptive, spiky, and unsuitable for a surface vehicle.
- Thunderbolt Network interfaces use None until their traffic shape is observed under meaningful load.

Keep one global, undisclosed application-session toggle. `C` enables or disables the selected resource's mapped utility, survives resource selection, and starts disabled on every launch. Hiding a utility, leaving its resource, or changing graph geometry clears its transient objects. Returning to an eligible resource recreates a fresh utility.

Replace graph-focus key handling with one window-level input router. It receives key-down, key-up, and repeat events regardless of the SwiftUI or SpriteKit first responder, dispatches resource-specific commands, and consumes only keys used by the active utility. Utility models receive semantic commands rather than AppKit events or key codes.

### Memory Boat

Place a small boat on the Memory usage boundary. Use a damped vertical spring to track the sampled line, produce brief bounded bobbing after level changes, and apply limited pitch from local slope. Do not add decorative waves or otherwise alter the displayed memory history.

Use the rover control model:

- `A` or Left moves left.
- `D` or Right moves right.
- Reversing first brakes existing movement.
- `R` resets above graph center.

Leaving the graph, changing selection, resizing, or disabling the global toggle resets or removes the boat. Space has no Boat action.

### Disk Tetromino

Use the seven classic tetromino shapes and familiar distinct colors with restrained outlines. A shuffled seven-piece bag provides the spawn sequence.

The active piece behaves like stripped-down classic Tetris:

- It descends, moves, and rotates in discrete block-sized steps.
- `A` or Left and `D` or Right move horizontally.
- Holding `S` or Down increases downward step cadence.
- `W` or Up rotates exactly 90 degrees per step.
- Key repeat produces repeated discrete movement rather than continuous force.

The active piece is controlled rather than dynamically simulated. Contact with Disk terrain or a settled piece ends control, converts it into a dynamic rigid body, and immediately spawns the next active piece. `R` releases the current piece as a dynamic body wherever it is and spawns its replacement.

There is no cell alignment, wall kick, placement correction, row detection, row clearing, score, preview, hold slot, or loss condition. Released pieces may tumble, collide, and accumulate. Remove fully offscreen bodies to keep physics bounded. Disabling the utility, leaving Disk, or resizing clears the complete pile and starts fresh next time.

### Network Packet

Draw a small winged data packet against the same adaptive path used for the Network graph. The utility applies to Wi-Fi and Ethernet but not Thunderbolt.

While flying:

- Keep its horizontal screen position at 30 percent from the graph's left edge.
- Apply gravity continuously.
- Treat each non-repeated Space press as one upward impulse.
- Use a soft top boundary that clamps the packet inside the graph, clears upward velocity, and does not count as a crash.
- Use swept collision against the current throughput path so narrow spikes cannot pass through it between frames.

Reset at the higher of 65 percent graph height or one packet-height above the path at the fixed horizontal position, capped by the soft ceiling. If the path leaves no safe clearance, collide immediately rather than granting temporary immunity.

On path collision, make the packet inert and attach it to the struck graph sample. Recalculate its displayed position from that sample and the current adaptive scale, allowing history movement to carry it left. Respawn after it is fully outside the left edge. `R` resets immediately whether the packet is flying or stuck. `A`, `D`, `W`, `S`, and arrow keys have no Packet action.

Keep Packet simulation independent of SpriteKit terrain bodies. The adaptive graph may redraw visible history, so drawing, live collision, and stuck attachment must derive from the same current graph data.

## Rationale

One vehicle does not fit every resource. Memory makes the car uninteresting because its surface stays nearly flat. Wi-Fi spikes throw a surface vehicle away from the data, and its adaptive scale can redraw history after exposure. Disk's long low sections provide useful falling space while its occasional spikes alter the pile.

The Boat makes Memory's level changes the main event. Tetrominos use Disk's empty vertical area and turn rare activity into obstacles without claiming to be a full game. The Packet treats Network as a changing hazard rather than immutable terrain and remains valid after adaptive rescaling.

A window-level input router removes accidental dependence on responder focus. Each Performance page has one selected graph, so utility command routing is unambiguous.

## Consequences

- Easter-egg dispatch expands from Car and None to Car, Boat, Tetromino, Packet, and None.
- Memory and Disk remain SpriteKit utilities on immutable physical terrain.
- Packet requires a simulation and collision layer integrated with the adaptive SwiftUI Network graph.
- Network descriptors need to distinguish Thunderbolt from Ethernet utility policy even when macOS reports both through Ethernet-class discovery.
- Automated checks cover command routing, lifecycle cleanup, buoyancy bounds, stepped tetromino control and dynamic conversion, object retention, swept packet collision, spawn safety, stuck attachment, rescaling, and reset.
- Manual inspection covers each utility under synthetic and useful live load, global state across resource switches, resize cleanup, both appearances, and input behavior with different controls focused.
