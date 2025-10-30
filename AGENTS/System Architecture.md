
# Beyond All Reason Live Data Export Widget - Research & Architecture Planning Document

## 1. Executive Overview

This document compiles research findings and architectural considerations for developing a Lua widget that extracts real-time game state data from Beyond All Reason and transmits it via TCP sockets to external tools. This serves as the foundational planning document for AI agent implementation.

---

## 2. Technology Stack & Environment Analysis

### 2.1 Game Engine Architecture

**Engine:** Beyond All Reason runs on the **Recoil Engine** (fork of Spring RTS Engine)

- **Lua Version:** 5.1/5.2 compatible environment
- **Widget System:** `barwidgets.lua` handler manages all UI widgets
- **Execution Context:** Single-threaded Lua sandbox with engine call-ins
- **Widget Location:** `/luaui/Widgets/` directory in game installation

### 2.2 Network Capabilities

**LuaSocket Integration:**

- Built into Spring/Recoil engine (confirmed in engine C++ source references)
- TCP connections enabled by default since Spring 98.0
- UDP connections remain restricted
- IPv4 support only (IPv6 not available in LuaSocket implementation)
- DNS resolution is **blocking** - requires workarounds

**Security Model:**

- Historical requirement: `TCPAllowConnect` configuration for external connections
- Modern versions: TCP client connections generally permitted
- Server sockets (listening ports) may require explicit configuration
- Widget cannot modify engine network settings - user must configure externally

### 2.3 Available JSON Libraries

**Recommended:** dkjson (David Kolf's JSON module)

- Pure Lua implementation - no external dependencies
- Available throughout Spring/BAR ecosystem
- Supports UTF-8 encoding
- Optional LPeg acceleration (if available)
- Handles special cases: `math.huge` → `null`, NaN → `null`
- Empty table handling via `__jsontype` metatable field

**Invocation Pattern:**

```lua
local json = require("dkjson")
-- or via VFS if bundled
local json = VFS.Include("path/to/dkjson.lua")
```

---

## 3. Widget Call-In System Research

### 3.1 Primary Update Hooks

The widget can respond to multiple engine-provided call-ins for different update frequencies:

**High-Frequency Options:**

- `widget:Update()` - Called every rendering frame (60+ FPS), receives `dt` (delta time)
- `widget:DrawWorld()` / `widget:DrawScreen()` - Called per render pass

**Game Logic Frequency:**

- `widget:GameFrame()` - Called every game simulation frame (30 Hz standard)
- `widget:GameProgress(serverFrameNum)` - Server-synchronized frame updates

**Initialization & Lifecycle:**

- `widget:Initialize()` - Widget startup, return false to disable
- `widget:Shutdown()` - Cleanup before widget unload
- `widget:GameStart()` - Triggered when game begins (post-pregame)

**Recommendation:** Use `widget:GameFrame()` for data collection to align with game simulation tick rate and avoid overwhelming network/external tool with render-frame frequency data.

### 3.2 Data Access APIs (Spring.Get* Functions)

**Unit State Data:**

- `Spring.GetAllUnits()` - Returns array of all unit IDs
- `Spring.GetUnitPosition(unitID)` - Returns x, y, z coordinates
- `Spring.GetUnitHealth(unitID)` - Returns health, maxHealth, paralyze, capture, build progress
- `Spring.GetUnitDefID(unitID)` - Returns unit definition ID
- `Spring.GetUnitTeam(unitID)` - Returns owning team ID
- `Spring.GetUnitVelocity(unitID)` - Returns movement vector

**Team/Player Data:**

- `Spring.GetTeamResources(teamID, "metal"|"energy")` - Returns current, storage, pull, income, expense
- `Spring.GetPlayerInfo(playerID)` - Returns name, isActive, isSpec, teamID, allyTeamID
- `Spring.GetTeamList()` - Returns array of team IDs
- `Spring.GetPlayerList()` - Returns array of player IDs

**Global Game State:**

- `Spring.GetGameFrame()` - Current simulation frame number
- `Spring.GetGameSeconds()` - Game time in seconds
- `Spring.GetGameSpeed()` - Current simulation speed multiplier
- `Game.mapSizeX`, `Game.mapSizeZ` - Map dimensions
- `Spring.IsPaused()` - Game pause state

**Visibility/LOS:**

- `Spring.GetVisibleUnits()` - Returns units visible to local player
- Widgets operate in **unsynced** context - access only to local player data
- Spectator mode grants full visibility via `Spring.IsGodMode()` or spec state

---

## 4. Network Architecture Considerations

### 4.1 Client vs Server Socket Design

**Option A: Widget as TCP Client (RECOMMENDED)**

- Widget connects to external tool listening on known host:port
- External tool controls connection lifecycle
- Simpler firewall/NAT traversal
- Reconnection logic handled by widget
- **Use Case:** Dashboard tool, statistics server, overlay application

**Option B: Widget as TCP Server**

- Widget opens listening port on localhost or LAN interface
- External tool initiates connection
- Allows multiple simultaneous tool connections
- Requires port forwarding/firewall configuration by user
- **Use Case:** Development/debugging, multiple concurrent consumers

**Decision Criteria:**

- Single external consumer → Client mode
- Multiple tools or dynamic connection → Server mode
- Production deployment → Client mode (less user configuration)

### 4.2 Non-Blocking I/O Implementation Strategy

**Critical Requirement:** All socket operations MUST be non-blocking to prevent game stuttering.

**Implementation Pattern:**

1. **Socket Initialization:**
    
    - Create socket: `socket.tcp()`
    - Set timeout to zero: `sock:settimeout(0)`
    - Attempt connection (returns immediately)
2. **Connection Management:**
    
    - Use `socket.select()` to poll socket readiness
    - Check writable state before sending
    - Handle "timeout" return as normal (not an error)
    - Detect "closed" state for reconnection logic
3. **Transmission Queue:**
    
    - Maintain Lua table queue for pending data packets
    - Send from queue when socket is writable
    - Drop oldest data if queue exceeds threshold (prevent memory leak)
4. **Coroutine Pattern (Advanced):**
    
    - Wrap connection/send operations in Lua coroutines
    - Yield control back to game loop
    - Resume on next frame when socket ready

**Error States to Handle:**

- `"timeout"` - Normal, socket not ready (continue)
- `"closed"` - Connection lost (attempt reconnect)
- `"refused"` - Server not available (retry with backoff)
- `nil` - Partial send success (queue remainder)

### 4.3 Data Framing Protocol

**Problem:** TCP is a byte stream - requires message boundaries.

**Solution Options:**

**Option 1: Newline Delimiter (Simple)**

```
{"frame":123,"units":[...]}\n
{"frame":124,"units":[...]}\n
```

- Pros: Simple to parse, human-readable
- Cons: JSON cannot contain literal newlines (must escape)

**Option 2: Length Prefix (Robust)**

```
[4-byte uint32 length][JSON payload bytes]
```

- Pros: Binary-safe, handles any JSON content
- Cons: Slightly more complex parsing

**Option 3: Custom Sentinel (Alternative)**

```
{"frame":123}\0\0\0\0
```

- Pros: Clear boundary marker
- Cons: Requires agreement with external tool

**Recommendation:** Newline delimiter for initial implementation (simplicity), with option to upgrade to length-prefix if issues arise.

---

## 5. Data Schema Design Considerations

### 5.1 Data Granularity Levels

**Level 1: Minimal (Every Frame)**

- Game frame number
- Game timestamp
- Pause state
- Player resource levels (metal, energy)

**Level 2: Standard (Configurable Frequency)**

- Level 1 data
- All visible unit positions
- Unit health percentages
- Build progress for constructors

**Level 3: Comprehensive (On-Demand)**

- Level 2 data
- Unit velocities
- Weapon reload states
- Team alliance status
- Map control statistics

**Recommendation:** Configurable data level via widget options, defaulting to Level 2.

### 5.2 Sample JSON Schema

```json
{
  "schema_version": "1.0",
  "timestamp": 1234567890,
  "game_frame": 9000,
  "game_seconds": 300.0,
  "is_paused": false,
  "game_speed": 1.0,
  "teams": [
    {
      "team_id": 0,
      "metal": {"current": 500, "income": 10, "storage": 1000},
      "energy": {"current": 3000, "income": 50, "storage": 5000}
    }
  ],
  "units": [
    {
      "id": 42,
      "def_id": 15,
      "team": 0,
      "pos": {"x": 1024, "y": 50, "z": 2048},
      "health": {"current": 850, "max": 1000},
      "build_progress": 1.0
    }
  ]
}
```

### 5.3 Serialization Performance

**Optimization Strategies:**

- **Incremental Updates:** Send only changed data (delta encoding)
- **Throttling:** Limit units per packet to avoid frame drops
- **Batching:** Accumulate data over N frames before serialization
- **Filtering:** Only serialize units within camera view or area of interest

**Performance Testing Required:**

- Measure JSON encoding time for 100/500/1000 unit arrays
- Target: <5ms serialization time per frame on typical hardware

---

## 6. Configuration & User Experience

### 6.1 Widget Configuration Structure

```lua
function widget:GetInfo()
  return {
    name = "Live Data Export Bridge",
    desc = "Exports real-time game data via TCP socket",
    author = "[Your Name]",
    date = "2025",
    license = "GNU GPL v2 or later",
    layer = 0,
    enabled = false, -- Disabled by default (user opt-in)
  }
end
```

**Configuration Options (via widget customization):**

- Target host/IP address (default: "127.0.0.1")
- Target port (default: 8765)
- Data export frequency (frames: 1, 5, 10, 30)
- Data granularity level (1-3)
- Auto-reconnect enabled (boolean)
- Max queue size (packets)
- Debug logging enabled (boolean)

### 6.2 Logging & Diagnostics

**Implementation via Spring.Echo():**

- Connection status changes (connected, disconnected, reconnecting)
- Error conditions (connection refused, send failures)
- Performance warnings (queue overflow, serialization >5ms)

**Log Levels:**

- INFO: Connection lifecycle events
- WARNING: Recoverable errors, performance degradation
- ERROR: Unrecoverable errors requiring user intervention

---

## 7. Security & Safety Considerations

### 7.1 Sandbox Limitations (Enforced by Engine)

**What Widgets CANNOT Do:**

- Access filesystem directly (read/write files)
- Execute system commands
- Load external dynamic libraries
- Modify engine configuration at runtime
- Access other players' data (in multiplayer, unless spectator)

**What Widgets CAN Do:**

- Create TCP connections (subject to engine restrictions)
- Read local player game state
- Send data over established connections
- Use VFS (Virtual File System) for read-only game resources

### 7.2 Data Privacy in Multiplayer

**Critical Consideration:** In multiplayer matches, widgets operate in **local player context**.

**Implications:**

- Widget can only export data visible to the local player
- Fog of War restrictions apply (no enemy unit data unless visible)
- Spectators have full visibility (if spectator mode enabled)

**Ethical Guidelines:**

- Document clearly that widget does NOT provide cheating advantage
- Only exports information already visible in-game
- Designed for overlay/statistics tools, not unfair advantage

### 7.3 Network Security

**Threat Model:**

- Widget connects to localhost or trusted LAN hosts only
- External tool validates incoming data structure
- No authentication mechanism in base implementation (optional future feature)
- Data transmitted in plaintext (JSON over TCP)

**Future Enhancement Options:**

- TLS/SSL support (requires external library - not in scope for v1)
- Shared secret token authentication
- Whitelist of allowed connection destinations

---

## 8. Error Handling & Resilience

### 8.1 Connection Lifecycle State Machine

**States:**

1. **DISCONNECTED** - Initial state, no connection
2. **CONNECTING** - Connection attempt in progress (non-blocking)
3. **CONNECTED** - Active connection, can send data
4. **RECONNECTING** - Connection lost, attempting to restore
5. **FAILED** - Connection failed, waiting for retry backoff

**Transitions:**

- DISCONNECTED → CONNECTING (on Initialize or manual trigger)
- CONNECTING → CONNECTED (socket select shows writable)
- CONNECTING → FAILED (connection refused/timeout after N attempts)
- CONNECTED → RECONNECTING (send returns "closed")
- FAILED → DISCONNECTED (after backoff period)

### 8.2 Retry & Backoff Strategy

**Exponential Backoff:**

- Initial retry: 1 second
- Subsequent retries: 2s, 4s, 8s, 16s, 32s (max)
- Reset backoff on successful connection
- Max retry attempts: Infinite (or configurable)

**Circuit Breaker Pattern:**

- After N consecutive failures (e.g., 10), pause retry for longer period
- Notify user via Spring.Echo() that connection is suspended
- Resume attempts on widget reload or manual trigger

---

## 9. Development & Testing Strategy

### 9.1 Development Environment Setup

**Required Components:**

1. BAR installation with dev mode enabled
2. Widget development location: `[BAR_Install]/data/games/BAR.sdd/luaui/Widgets/`
3. External test tool (Python/Node.js TCP server)
4. JSON validation tool

**Testing Workflow:**

1. Create widget in Widgets directory
2. Launch BAR in dev mode
3. Widget auto-loads (or use `/luaui reload`)
4. External tool receives data stream
5. Iterate on widget code (hot-reload supported)

### 9.2 Mock External Tool (Python Example)

Simple TCP server to receive and validate data:

```python
import socket
import json

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.bind(('127.0.0.1', 8765))
server.listen(1)
print("Listening for BAR widget connection...")

conn, addr = server.accept()
print(f"Connected: {addr}")

buffer = ""
while True:
    data = conn.recv(4096)
    if not data:
        break
    buffer += data.decode('utf-8')
    while '\n' in buffer:
        line, buffer = buffer.split('\n', 1)
        try:
            packet = json.loads(line)
            print(f"Frame {packet.get('game_frame')}: {len(packet.get('units', []))} units")
        except json.JSONDecodeError as e:
            print(f"JSON Error: {e}")
```

### 9.3 Test Scenarios

**Functional Tests:**

1. Widget connects to external tool successfully
2. Data packets arrive with valid JSON structure
3. Unit positions match in-game locations
4. Resource values update correctly
5. Connection survives game pause/unpause

**Stress Tests:**

1. Export 500+ units without frame drops
2. Connection resilience (kill/restart external tool)
3. Network latency simulation
4. Memory leak detection (long-running game sessions)

**Edge Cases:**

1. Widget loaded mid-game (should connect gracefully)
2. No external tool running (should queue and retry)
3. External tool disconnects unexpectedly
4. Game speed changes (0.1x, 10x)

---

## 10. Implementation Phases

### Phase 1: Core Socket & Connection Management

**Deliverables:**

- Non-blocking TCP client implementation
- Connection state machine
- Retry/backoff logic
- Basic logging

**Success Criteria:** Widget establishes and maintains connection to test server.

### Phase 2: Data Collection & Serialization

**Deliverables:**

- GameFrame call-in hook
- Basic data schema (game state + visible units)
- JSON serialization via dkjson
- Transmission queue

**Success Criteria:** External tool receives valid JSON packets with game state data.

### Phase 3: Configuration & Optimization

**Deliverables:**

- Widget configuration options
- Data granularity levels
- Performance optimization (throttling, filtering)
- Enhanced logging

**Success Criteria:** Widget performs well with 500+ units, configurable via UI.

### Phase 4: Polish & Documentation

**Deliverables:**

- Comprehensive code comments
- User documentation (installation, configuration)
- API documentation for external tool developers
- Example integrations

**Success Criteria:** Third-party developers can consume data stream to build overlay tools.

---

## 11. Technical Specifications for AI Agent

### 11.1 File Structure

**Primary Widget File:** `export_livedata.lua`

- Location: `luaui/Widgets/`
- Dependencies: dkjson (bundled or via VFS)

**Optional Files:**

- `export_livedata_config.lua` - User configuration
- `README_export_livedata.md` - Documentation

### 11.2 Required Modules/Libraries

**LuaSocket:** (Built into engine)

- `socket.tcp()` - TCP socket creation
- `socket.select()` - Non-blocking I/O polling

**JSON Serialization:**

- dkjson library (pure Lua, no dependencies)
- Include via VFS or embed in widget

**Spring Engine APIs:**

- All `Spring.Get*()` functions for data access
- `Spring.Echo()` for logging
- `widget:GameFrame()` call-in

### 11.3 Key Implementation Guidelines

**DO:**

- Use `settimeout(0)` immediately after socket creation
- Handle all socket operation return values (including "timeout")
- Implement exponential backoff for reconnection
- Limit data packet size to avoid frame drops
- Log all connection state changes
- Document configuration options clearly

**DO NOT:**

- Block the game loop (no blocking socket calls)
- Assume connection is always available
- Send unbounded data without throttling
- Ignore error return values from socket operations
- Access filesystem or OS resources
- Make assumptions about network reliability

---

## 12. Comparison with Existing Solutions

### 12.1 Replay Analysis vs Live Data Export

**Replay Files (Existing):**

- Post-match analysis only
- Complete game state available
- Processed offline
- Engine-generated automatically

**Live Data Export (This Widget):**

- Real-time streaming
- Powers live overlays/dashboards
- External tools can react during game
- Requires widget implementation

**Use Case Differentiation:** This widget enables live broadcast tools, in-game statistics overlays, and real-time analysis - not possible with replays.

### 12.2 Related Projects Research

**BAR Headless Mode:** (For replay processing)

- Runs game without graphics
- Generates statistics from replays
- Not applicable to live game streaming

**Existing Overlay Widgets:**

- Render directly in-game (GUI widgets)
- No external tool integration
- Limited to in-game Lua capabilities

**Gap Filled:** This widget bridges BAR and external tool ecosystems.

---

## 13. Risk Assessment & Mitigation

### 13.1 Technical Risks

|Risk|Impact|Likelihood|Mitigation|
|---|---|---|---|
|Performance degradation (>500 units)|High|Medium|Implement throttling, delta updates, profiling|
|Network instability (packet loss)|Medium|High|Queue buffering, reconnection logic|
|JSON serialization overhead|Medium|Low|Optimize schema, benchmark dkjson|
|Socket API changes in engine updates|High|Low|Monitor engine changelog, version checks|

### 13.2 Security Risks

|Risk|Impact|Likelihood|Mitigation|
|---|---|---|---|
|Malicious external tool|Medium|Low|Document localhost-only recommendation|
|Data leakage in multiplayer|Low|Low|Widget only accesses local player data|
|Widget exploit|Low|Very Low|Lua sandbox prevents OS access|

---

## 14. Success Metrics

**Functional Metrics:**

- [ ] Widget connects to external tool within 5 seconds
- [ ] Data packets arrive at 30 Hz (1 per game frame)
- [ ] JSON parse success rate >99.9%
- [ ] Handles 500+ units without frame drops (<1ms impact)

**User Experience Metrics:**

- [ ] Clear connection status indication
- [ ] Graceful failure handling (no crashes)
- [ ] Comprehensive error messages
- [ ] Easy configuration (<5 minutes setup)

**Developer Metrics:**

- [ ] Well-documented API for external tools
- [ ] Example implementations available
- [ ] Active community adoption (GitHub stars, forum posts)

---

## 15. Next Steps for Implementation

### For AI Agent (Claude Code):

1. **Read this document thoroughly** - Understand architecture decisions and constraints
2. **Create primary widget file** - Implement core socket connection logic first
3. **Add data collection layer** - Integrate Spring API calls for game state
4. **Implement JSON serialization** - Use dkjson for data encoding
5. **Add error handling** - Robust connection management and retry logic
6. **Write comprehensive comments** - Explain non-obvious implementation details
7. **Create user documentation** - Installation, configuration, troubleshooting guide

### For Testing:

1. **Create simple Python TCP server** - Validates incoming data stream
2. **Test connection lifecycle** - Connect, disconnect, reconnect scenarios
3. **Stress test with units** - Spawn 100, 500, 1000 units and measure performance
4. **Verify JSON schema** - Ensure all data fields are present and valid

### For Documentation:

1. **API specification** - JSON schema documentation for external tool developers
2. **User guide** - Screenshots, configuration examples
3. **Developer guide** - How to extend widget, add new data fields

---

## 16. References & Resources

**Beyond All Reason:**

- Main Repository: https://github.com/beyond-all-reason/Beyond-All-Reason
- Recoil Engine: https://github.com/beyond-all-reason/RecoilEngine
- Lua API Documentation: https://beyond-all-reason.github.io/RecoilEngine/docs/lua-api/

**Spring Engine (Parent Project):**

- LuaSocket Documentation: https://springrts.com/wiki/Lua_Socket
- Widget Development: https://springrts.com/wiki/Lua_Widget

**Libraries:**

- dkjson: http://dkolf.de/dkjson-lua/
- LuaSocket Manual: http://w3.impa.br/~diego/software/luasocket/

**Community:**

- BAR Discord: discord.gg/beyond-all-reason
- Development Forum: https://www.beyondallreason.info/development

---

## Document Control

**Version:** 1.0  
**Date:** 2025-01-28  
**Author:** Research & Planning Phase  
**Next Review:** Post-Implementation  
**Status:** Ready for AI Agent Implementation

---

This research document provides comprehensive guidance for implementing the Live Data Export Widget. All architectural decisions are backed by verified capabilities of the BAR/Recoil engine and established best practices for non-blocking network I/O in Lua environments.