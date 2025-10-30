# Beyond All Reason Live Data Export Widget - Implementation Specification Document

## Document Purpose

This specification provides detailed implementation guidance for AI coding agents (e.g., Claude Code CLI) to develop the Live Data Export Widget in manageable phases. Each phase builds upon previous work to create a production-ready Minimum Viable Product Plus (MVP+).

---

## 1. Project Overview & Objectives

### 1.1 Core Mission

Create a robust, performant Lua widget that extracts real-time game state data from Beyond All Reason and transmits it via TCP sockets to external consumer applications, enabling live overlays, analytics dashboards, and broadcast tools.

### 1.2 MVP+ Definition

The MVP+ includes not just basic functionality, but also essential production features:

- Stable non-blocking network communication
- Configurable data export options
- Comprehensive error handling and recovery
- Performance optimization for large-scale battles
- User-friendly configuration interface
- Clear status feedback and diagnostics

### 1.3 Success Criteria

- Widget loads without errors in BAR
- Establishes and maintains TCP connection to external tool
- Exports game state data at consistent frame rate
- Handles network failures gracefully
- Performs efficiently with 500+ concurrent units
- Provides clear user feedback on connection status

---

## 2. Phase 1: Foundation & Socket Infrastructure

### 2.1 Phase Objectives

Establish the fundamental network communication layer with robust connection management, providing a solid foundation for all subsequent phases.

### 2.2 Core Components to Implement

#### Widget Metadata Structure

Create the widget information table following BAR conventions:

- Widget name, description, author, date
- License declaration (GNU GPL v2 or later recommended)
- Layer specification (0 is standard)
- Enabled state (default false for user opt-in)
- Version number for tracking

#### Configuration System

Implement a configuration structure that stores:

- Target host IP address (default localhost)
- Target port number (default 8765)
- Connection retry parameters (initial delay, max delay, backoff multiplier)
- Enable/disable flags for features
- Debug logging level

Support for configuration persistence:

- Use widget:GetConfigData() for saving user preferences
- Use widget:SetConfigData() for loading saved preferences
- Provide sensible defaults for all options

#### Connection State Management

Design a state machine with the following states:

- DISCONNECTED: Initial state, no connection exists
- CONNECTING: Non-blocking connection attempt in progress
- CONNECTED: Active connection established and verified
- RECONNECTING: Connection lost, attempting to restore
- FAILED: Connection attempts exhausted, awaiting retry timer

Implement state transition logic:

- Clear rules for moving between states
- Timeout handling for connection attempts
- State persistence across widget updates

#### Socket Operations Module

Create the core socket management functionality:

**Socket Initialization:**

- Create TCP socket using LuaSocket
- Configure socket for non-blocking operation (timeout zero)
- Store socket handle in widget state

**Connection Logic:**

- Implement non-blocking connect to target host:port
- Use socket.select() to poll connection readiness
- Handle connection success, timeout, and refusal cases
- Support both immediate connection and delayed establishment

**Connection Verification:**

- Detect when socket becomes writable (connection complete)
- Implement connection health checks
- Detect disconnection through send operation failures

**Socket Cleanup:**

- Proper socket closure on widget shutdown
- Resource deallocation
- State reset for clean restart

#### Error Handling Framework

Establish comprehensive error handling patterns:

**Socket Error Categories:**

- Timeout (normal non-blocking behavior, not an error)
- Connection refused (server not available)
- Connection closed (server disconnected)
- Send failure (partial or complete)

**Error Response Strategies:**

- Log all errors with appropriate severity
- Transition to appropriate connection state
- Preserve error context for debugging
- Avoid cascading failures

**Logging System:**

- Use Spring.Echo() for user-visible messages
- Implement log level filtering (ERROR, WARNING, INFO, DEBUG)
- Include timestamps and context in log messages
- Prevent log spam with message throttling

### 2.3 Widget Lifecycle Integration

#### Initialization (widget:Initialize)

Implement startup sequence:

- Load configuration from saved data or defaults
- Initialize connection state machine
- Initialize logging system
- Print startup banner with version and configuration
- Return false if initialization fails critically

#### Update Loop Integration (widget:Update)

Create the main update function that receives delta time:

- Process connection state machine transitions
- Handle socket select polling
- Manage reconnection timers
- Update retry backoff calculations
- Avoid blocking operations

#### Graceful Shutdown (widget:Shutdown)

Implement cleanup procedure:

- Close active socket connections
- Save current configuration
- Clear state variables
- Log shutdown message

### 2.4 Reconnection & Resilience Logic

#### Exponential Backoff Algorithm

Implement retry delay calculation:

- Start with initial delay (e.g., 1 second)
- Double delay on each failure up to maximum
- Reset delay on successful connection
- Add jitter to prevent thundering herd

#### Retry Attempt Tracking

Maintain retry statistics:

- Count consecutive failures
- Track total connection attempts
- Record last successful connection time
- Calculate connection uptime percentage

#### Circuit Breaker Pattern

Implement failure threshold detection:

- After N consecutive failures, enter cooldown period
- Extend cooldown period progressively
- Notify user of suspended connection attempts
- Provide manual reconnection trigger

### 2.5 Testing Requirements for Phase 1

#### Unit Test Scenarios

The implementation should be testable for:

- Socket creation succeeds without errors
- Non-blocking configuration applied correctly
- Connection to available server succeeds
- Connection to unavailable server triggers retry logic
- State machine transitions correctly through all states
- Exponential backoff calculates delays correctly

#### Integration Test Scenarios

Verify behavior with actual BAR environment:

- Widget loads in BAR without errors
- Configuration persists across widget reloads
- Logging appears correctly in BAR console
- Widget survives BAR pause/unpause
- Widget handles game restart gracefully

#### Manual Test Procedures

Document steps for human verification:

- Launch BAR with widget enabled
- Start external test server on configured port
- Observe connection success log message
- Stop external server, observe reconnection attempts
- Restart server, verify automatic reconnection
- Reload widget, verify configuration persistence

### 2.6 Deliverables for Phase 1

**Primary File:**

- `export_livedata.lua` with complete socket infrastructure

**Expected Capabilities:**

- Widget loads and initializes correctly
- Establishes TCP connection to external server
- Maintains connection with health checks
- Recovers from connection failures automatically
- Logs connection events clearly
- Persists user configuration

**Quality Benchmarks:**

- Zero crashes or errors in normal operation
- Connection established within 5 seconds when server available
- Reconnection occurs within 30 seconds of server restart
- Clear log messages for all connection state changes

---

## 3. Phase 2: Data Collection & Schema Implementation

### 3.1 Phase Objectives

Implement comprehensive game state data collection using Spring engine APIs, structure data into well-defined schemas, and prepare for serialization.

### 3.2 Data Access Layer

#### Spring API Integration

Create functions that wrap Spring engine API calls:

**Global Game State Functions:**

- Retrieve current game frame number
- Calculate game time in seconds
- Determine game speed multiplier
- Check pause state
- Get map dimensions

**Unit Data Collection Functions:**

- Get list of all visible units (respecting LOS)
- For each unit retrieve:
    - Unit ID (unique identifier)
    - Unit Definition ID (type of unit)
    - Owner team ID
    - Current position coordinates (x, y, z)
    - Health and maximum health
    - Build progress (for units under construction)
    - Velocity vector (if needed for advanced mode)

**Team/Player Data Collection Functions:**

- Get list of active teams
- For each team retrieve:
    - Metal resources (current, income, expense, storage)
    - Energy resources (current, income, expense, storage)
    - Team color for visualization
- Get player information:
    - Player name
    - Player ID
    - Associated team
    - Spectator status

**Visibility Context Handling:**

- Determine if local player is spectator
- Apply appropriate data filtering based on LOS
- Handle full visibility mode for spectators
- Respect fog of war in normal gameplay

#### Data Collection Optimization

**Incremental Update Strategy:**

- Maintain previous frame state in memory
- Calculate deltas between frames
- Only serialize changed data when appropriate
- Implement full snapshot at regular intervals

**Throttling Mechanisms:**

- Configurable data collection frequency (every N frames)
- Unit count limits per packet
- Priority-based unit selection (visible, selected, nearby)
- Area-of-interest filtering around camera position

**Performance Budgeting:**

- Set maximum execution time per frame (target <2ms)
- Implement early termination if budget exceeded
- Queue remaining work for next frame
- Monitor and log performance metrics

### 3.3 Data Schema Design

#### Schema Versioning

Implement version tracking:

- Include schema version number in every packet
- Document schema changes between versions
- Provide backward compatibility guidance
- Enable external tools to handle multiple versions

#### Core Data Structure

Design the primary data packet structure:

**Packet Header:**

- Schema version identifier
- Packet sequence number (incrementing)
- Timestamp (system time or game time)
- Packet type identifier (full snapshot vs delta)

**Game State Object:**

- Current game frame number
- Game seconds elapsed
- Simulation speed multiplier
- Pause state boolean
- Map dimensions (static, can be sent once)

**Team Data Array:** For each team include:

- Team identifier
- Metal resource object (current, income, expense, storage, share)
- Energy resource object (same fields as metal)
- Optional: team statistics (units, kills, losses)

**Unit Data Array:** For each unit include:

- Unit identifier (integer)
- Unit definition ID (integer)
- Owning team ID
- Position object (x, y, z coordinates)
- Health object (current, maximum)
- Build progress (0.0 to 1.0)
- Optional extended data (velocity, heading, orders)

#### Schema Variants

**Minimal Schema (High Frequency):**

- Core game state only
- Resource levels
- Unit positions (sparse sampling)
- Optimized for low bandwidth

**Standard Schema (Default):**

- Full game state
- Complete unit data for visible units
- Team resources
- Balanced detail and performance

**Comprehensive Schema (Low Frequency):**

- Everything in Standard
- Unit velocities and headings
- Weapon states
- Build queues
- Team statistics

### 3.4 Data Collection Scheduling

#### Frame-Based Collection

Implement collection triggers:

**Primary Collection Hook:**

- Use widget:GameFrame() for simulation-synchronized collection
- Ensures data aligns with game logic updates
- Provides consistent 30 Hz baseline

**Collection Frequency Control:**

- Configurable frame interval (collect every 1, 5, 10, 30 frames)
- Frame counter tracking
- Modulo arithmetic for interval checking

**Priority Queue System:**

- High priority: Game state, player resources
- Medium priority: Visible unit positions
- Low priority: Extended unit data
- Spread work across multiple frames if needed

#### Dynamic Frequency Adjustment

Implement adaptive collection rates:

- Monitor packet send success rate
- Reduce frequency if network queue backing up
- Increase frequency if queue empty and bandwidth available
- Respect user-configured minimum/maximum rates

### 3.5 Data Filtering & Privacy

#### Line of Sight Filtering

Implement visibility rules:

- Check if local player is spectator
- If not spectator, filter units by visibility
- Use Spring.GetVisibleUnits() for efficient filtering
- Never expose hidden enemy units

#### Data Sanitization

Ensure multiplayer fairness:

- Only export data visible to local player
- Remove server-authoritative data not in UI
- Document privacy guarantees clearly
- Prevent accidental information leakage

### 3.6 Memory Management

#### Data Structure Reuse

Optimize memory allocation:

- Preallocate Lua tables for data collection
- Reuse tables across frames instead of creating new
- Clear table contents rather than discarding
- Minimize garbage collection pressure

#### Memory Monitoring

Implement tracking:

- Monitor Lua memory usage trends
- Log warnings if memory growth detected
- Implement data structure size limits
- Provide memory usage statistics in debug mode

### 3.7 Testing Requirements for Phase 2

#### Data Accuracy Tests

Verify correctness:

- Unit positions match visual locations in-game
- Resource values match UI display
- Game time advances correctly
- Unit counts match expected values

#### Performance Tests

Measure efficiency:

- Data collection time per frame with varying unit counts
- Memory allocation per collection cycle
- Table reuse effectiveness
- Garbage collection frequency

#### Edge Case Tests

Handle unusual scenarios:

- Zero units (game start)
- Massive unit counts (500+)
- Rapid unit creation/destruction
- Game speed changes (0.5x to 10x)
- Pause and unpause

### 3.8 Deliverables for Phase 2

**Enhanced Widget File:**

- Data collection functions integrated
- Schema structure definitions
- Collection scheduling logic
- Performance monitoring

**Expected Capabilities:**

- Collects complete game state every frame (or configured interval)
- Structures data into well-defined schema
- Filters data according to visibility rules
- Operates within performance budget (<2ms per frame)
- Handles edge cases gracefully

**Quality Benchmarks:**

- Data collection completes in <2ms for 500 units
- Memory stable over 1-hour game session
- Zero crashes with rapid unit spawning
- Accurate data verified against in-game UI

---

## 4. Phase 3: JSON Serialization & Transmission Pipeline

### 4.1 Phase Objectives

Transform collected game state data into JSON format and transmit it reliably over the established TCP connection, ensuring data integrity and optimal performance.

### 4.2 JSON Serialization Implementation

#### dkjson Integration

Integrate the JSON library:

**Library Loading:**

- Determine if dkjson is available via require()
- If not available, include bundled copy via VFS.Include()
- Handle loading errors gracefully
- Verify library version compatibility

**Serialization Function Wrapper:** Create abstraction for encoding:

- Accept Lua table as input
- Call json.encode() with appropriate options
- Handle encoding errors (invalid data types)
- Return JSON string or error indicator
- Log serialization failures with context

**Encoding Options Configuration:**

- Disable indentation for compact output
- Handle special values (infinity, NaN as null)
- Configure empty table handling (array vs object)
- Set appropriate key ordering if needed

#### Serialization Optimization

**Data Preparation:**

- Ensure all table keys are JSON-compatible (strings or numbers)
- Convert incompatible types before serialization
- Remove metatable references that shouldn't be encoded
- Pre-validate data structure depth

**Performance Profiling:**

- Measure serialization time per packet
- Log warnings if encoding exceeds threshold (e.g., 5ms)
- Implement serialization budget per frame
- Consider splitting large packets if needed

**Caching Strategies:**

- Cache static data (map info, unit definitions)
- Send cached data once at connection start
- Reference cached data by ID in subsequent packets
- Implement cache invalidation on game state change

### 4.3 Transmission Queue Management

#### Queue Data Structure

Implement efficient packet queue:

**Queue Implementation:**

- Use Lua table as circular buffer or simple array
- Store serialized JSON strings ready for transmission
- Include metadata (timestamp, sequence number, priority)
- Track queue size and memory usage

**Queue Operations:**

- Enqueue: Add new packet to end
- Dequeue: Remove and return next packet
- Peek: View next packet without removing
- Clear: Empty entire queue

**Queue Limits:**

- Configure maximum queue size (number of packets)
- Configure maximum memory usage (bytes)
- Implement overflow handling strategies
- Monitor queue depth statistics

#### Queue Overflow Handling

**Overflow Strategies:** Define behavior when queue full:

**Drop Oldest:**

- Remove oldest packet to make room
- Prioritize recent data over historical
- Log dropped packet count

**Drop New:**

- Reject new packet if queue full
- Preserve historical data stream
- May cause temporal gaps

**Priority-Based:**

- Assign priority to different data types
- Drop low-priority packets first
- Preserve critical game state updates

**Backpressure:**

- Reduce collection frequency when queue grows
- Resume normal rate when queue drains
- Dynamic throttling based on queue depth

### 4.4 Non-Blocking Transmission Logic

#### Socket Writability Detection

Implement polling mechanism:

**Select-Based Polling:**

- Call socket.select() with socket in writable set
- Set timeout to zero for non-blocking check
- Interpret results: ready, timeout, error
- Only attempt send when socket ready

**Polling Frequency:**

- Check writability every widget update cycle
- Balance between responsiveness and overhead
- Avoid excessive select() calls

#### Send Operation Handling

Implement robust transmission:

**Sending Procedure:**

- Dequeue next packet from queue
- Attempt socket:send() with JSON string
- Handle partial send (only some bytes transmitted)
- Handle send errors (closed, timeout)

**Partial Send Recovery:**

- Track number of bytes successfully sent
- Keep remaining bytes in queue or temporary buffer
- Retry unsent portion on next writable event
- Avoid data duplication or loss

**Error Handling:**

- Treat "timeout" as normal (try again later)
- Treat "closed" as connection loss (reconnect)
- Log unexpected errors with full context

### 4.5 Message Framing Protocol

#### Delimiter Implementation

Add message boundaries:

**Newline Delimiter Approach:**

- Append newline character to each JSON packet
- Ensure JSON doesn't contain literal newlines
- Document delimiter choice for external tools
- Simple parsing on receiving end

**Length Prefix Alternative:** If newline delimiter insufficient:

- Prepend 4-byte integer with payload length
- Encode length in network byte order (big-endian)
- Provides binary-safe framing
- Slightly more complex parsing

**Implementation Selection:**

- Default to newline delimiter for simplicity
- Provide configuration option for length prefix
- Document framing format in API specification

### 4.6 Transmission Monitoring & Diagnostics

#### Performance Metrics

Track transmission statistics:

**Counters to Maintain:**

- Total packets queued
- Total packets transmitted successfully
- Total bytes transmitted
- Packets dropped due to overflow
- Partial sends recovered
- Transmission errors

**Rate Calculations:**

- Packets per second transmission rate
- Bytes per second bandwidth usage
- Average packet size
- Queue depth over time

**Diagnostic Logging:**

- Log statistics at regular intervals (optional)
- Provide statistics query command
- Include metrics in debug mode output

#### Flow Control

**Adaptive Transmission:**

- Monitor queue depth trends
- If queue growing, signal backpressure to collection
- If queue empty, signal capacity available
- Balance collection rate with transmission capacity

**Congestion Detection:**

- Detect prolonged queue growth
- Warn user of potential network issues
- Consider reducing data granularity automatically

### 4.7 Data Integrity Verification

#### Packet Sequencing

Implement ordering guarantees:

**Sequence Numbers:**

- Assign incrementing sequence number to each packet
- Include sequence number in JSON packet
- Wrap sequence number at maximum (e.g., 2^32)
- Enable receiver to detect gaps or reordering

**Packet Types:**

- Full snapshot (complete game state)
- Delta update (changes only)
- Heartbeat (connection keepalive)
- Control message (configuration change)

#### Checksums (Optional)

Consider data validation:

- Calculate checksum of JSON payload
- Include checksum in packet header
- Receiver validates checksum
- Detect corruption during transmission
- May be unnecessary for TCP (already checksummed)

### 4.8 Testing Requirements for Phase 3

#### Serialization Tests

Verify JSON encoding:

- All data types serialize correctly
- Special values (infinity, nil) handled
- No encoding errors with valid data
- Output is valid JSON (parseable)

#### Transmission Tests

Verify reliable delivery:

- Packets arrive at external tool
- Packets arrive in order
- No data loss under normal conditions
- Partial sends recovered correctly

#### Performance Tests

Measure efficiency:

- Serialization time for varying payload sizes
- Transmission throughput (packets/second)
- Queue memory usage under load
- CPU overhead of serialization

#### Stress Tests

Verify robustness:

- Handle 100+ packets queued
- Survive rapid connection open/close cycles
- Recover from sustained network unavailability
- Maintain performance with 1000+ units

### 4.9 Deliverables for Phase 3

**Complete Widget File:**

- JSON serialization integrated
- Transmission queue implemented
- Non-blocking send logic
- Message framing

**Expected Capabilities:**

- Serializes game state to JSON format
- Queues packets for transmission
- Sends packets without blocking game
- Handles network congestion gracefully
- Provides transmission statistics

**Quality Benchmarks:**

- Serialization completes in <3ms for standard packet
- Transmits 30 packets/second reliably
- Queue never exceeds 10 packets in normal conditions
- Zero data corruption or loss in testing
- Handles 500+ units with <5ms total overhead

---

## 5. Phase 4: Configuration Interface & User Experience

### 4.1 Phase Objectives

Create an intuitive configuration system that allows users to customize widget behavior, provides clear status feedback, and integrates seamlessly with BAR's UI conventions.

### 4.2 Configuration Options Definition

#### Connection Settings

Define user-configurable network parameters:

**Target Host Configuration:**

- IP address or hostname string
- Default value: "127.0.0.1" (localhost)
- Validation: basic format check, no DNS resolution
- Help text: "IP address of external tool (localhost recommended)"

**Target Port Configuration:**

- Port number integer (1-65535)
- Default value: 8765
- Validation: range check
- Help text: "TCP port number for external tool connection"

**Connection Behavior:**

- Auto-connect on widget load (boolean, default true)
- Auto-reconnect on disconnect (boolean, default true)
- Maximum reconnection attempts (integer, 0 = unlimited)
- Reconnection delay multiplier (float, default 2.0)

#### Data Export Settings

Define collection and transmission parameters:

**Export Frequency:**

- Frames between exports (integer: 1, 5, 10, 30)
- Default: 1 (every frame)
- Options: Every frame, Every 5 frames, Every 10 frames, Every second
- Help text: "How often to send data updates"

**Data Granularity Level:**

- Minimal (level 1): core game state and resources
- Standard (level 2): includes all visible units (default)
- Comprehensive (level 3): includes extended unit data
- Help text: "Amount of detail in exported data"

**Unit Filter Options:**

- Export only selected units (boolean, default false)
- Export only units in camera view (boolean, default false)
- Maximum units per packet (integer, 0 = unlimited, default 500)
- Help text: "Reduce data volume by filtering units"

#### Performance Settings

Define resource management options:

**Queue Configuration:**

- Maximum queue size (packets, default 50)
- Queue overflow strategy (dropdown: drop oldest/drop new/priority)
- Help text: "How to handle network congestion"

**Performance Limits:**

- Maximum serialization time per frame (milliseconds, default 5)
- Enable adaptive throttling (boolean, default true)
- Help text: "Prevent game performance degradation"

#### Diagnostic Settings

Define logging and debugging options:

**Logging Level:**

- Off: No logging
- Error: Only critical errors
- Warning: Errors and warnings
- Info: General information (default)
- Debug: Verbose diagnostic output
- Help text: "Console message verbosity"

**Statistics Display:**

- Show connection status in console (boolean, default true)
- Show transmission statistics (boolean, default false)
- Statistics update interval (seconds, default 10)

### 4.3 Configuration Persistence

#### Save/Load Implementation

Implement configuration storage:

**Save Mechanism (widget:GetConfigData):**

- Serialize current configuration to Lua table
- Include all user-configurable options
- Exclude runtime state (connection status, etc.)
- Return table for BAR to persist

**Load Mechanism (widget:SetConfigData):**

- Receive persisted configuration table
- Validate all values (type and range checks)
- Apply defaults for missing values
- Handle configuration version migration

**Configuration Validation:**

- Check data types for all fields
- Clamp numeric values to valid ranges
- Sanitize string values
- Log validation errors and use defaults

#### Configuration Migration

Handle version changes:

**Version Tracking:**

- Store configuration schema version
- Detect old configuration formats
- Apply migration transformations
- Document breaking changes

### 4.4 User Interface Integration

#### Widget Options Menu

Create configuration UI within BAR:

**Option Panel Structure:** If BAR supports custom widget options UI:

- Group related settings into sections
- Use appropriate UI controls (text input, dropdown, checkbox, slider)
- Provide real-time validation feedback
- Show current values clearly

**Console Commands:** Alternative or supplementary interface:

- Define slash commands for configuration changes
- Examples: /export_host 192.168.1.100, /export_port 9000
- Provide command help text
- Confirm configuration changes in console

#### WG (Widget Global) Interface

Expose programmatic configuration:

**API Functions:** Create WG['export_livedata'] table with functions:

- getConfig(): return current configuration table
- setConfig(options): update configuration values
- getStatus(): return connection status and statistics
- connect(): manually trigger connection
- disconnect(): manually close connection

**Use Cases:**

- Allow other widgets to query/control export widget
- Enable advanced users to script configurations
- Support automated testing

### 4.5 Status Feedback System

#### Connection Status Display

Provide clear status indication:

**Status Messages:**

- "Disconnected - waiting to connect"
- "Connecting to [host]:[port]..."
- "Connected - exporting data"
- "Reconnecting (attempt N/M)..."
- "Connection failed - will retry in Xs"
- "Connection suspended - manual reconnect required"

**Message Timing:**

- Show status change immediately
- Throttle repeated messages (avoid spam)
- Use color coding if BAR console supports it

#### Visual Indicators

If implementing custom UI elements:

**Status Indicator Widget:**

- Small icon showing connection state (optional)
- Color-coded: green=connected, yellow=connecting, red=disconnected
- Tooltip with detailed status on hover
- Click to open configuration or retry connection

#### Diagnostic Output

**Connection Diagnostics:**

- Display target host:port in status
- Show time since last successful connection
- Display current queue depth
- Show transmission rate (packets/second)

**Error Reporting:**

- Specific error messages for different failure types
- Suggestions for resolution (check server, check firewall)
- Error codes for technical debugging

### 4.6 Help & Documentation Integration

#### In-Widget Documentation

Provide context-sensitive help:

**Command Help:**

- List all console commands
- Display usage syntax
- Provide examples
- Show current values

**Configuration Help:**

- Explain each option's purpose
- Describe valid value ranges
- Warn about performance implications
- Link to external documentation

#### Readme File

Create comprehensive user guide:

**README_export_livedata.md content:**

- Widget purpose and use cases
- Installation instructions
- Configuration guide with screenshots
- Troubleshooting common issues
- FAQ section
- External tool integration examples

**API Documentation:**

- JSON schema specification
- Connection protocol details
- Example packet captures
- Client implementation guide

### 4.7 Testing Requirements for Phase 4

#### Configuration Tests

Verify settings management:

- All options settable via supported interfaces
- Configuration persists across widget reload
- Invalid values rejected gracefully
- Defaults applied correctly

#### User Experience Tests

Verify usability:

- Status messages appear as expected
- Configuration changes take effect immediately (or after reconnect)
- Help text is clear and accurate
- Error messages are helpful

#### Integration Tests

Verify BAR compatibility:

- Widget loads with default configuration
- Configuration UI appears correctly
- Console commands work as documented
- WG interface accessible to other widgets

### 4.8 Deliverables for Phase 4

**Enhanced Widget File:**

- Complete configuration system
- User interface integration
- Status feedback mechanisms
- Help documentation

**Supporting Files:**

- README.md with user documentation
- SCHEMA.md with API specification
- Example configuration files

**Expected Capabilities:**

- Users can configure all aspects of widget behavior
- Configuration persists between sessions
- Clear feedback on connection status
- Comprehensive help available
- Easy troubleshooting of common issues

**Quality Benchmarks:**

- Configuration UI intuitive (testable by novice user)
- All status changes logged clearly
- Zero configuration-related crashes
- Documentation complete and accurate

---

## 6. Phase 5: Optimization, Polish & Production Readiness

### 6.1 Phase Objectives

Refine the widget for production deployment with performance optimization, comprehensive testing, edge case handling, and final polish to ensure reliability and user satisfaction.

### 6.2 Performance Optimization

#### Profiling & Measurement

Implement performance instrumentation:

**Timing Instrumentation:**

- Measure each major operation's execution time
- Track data collection duration
- Track serialization duration
- Track transmission duration
- Calculate total overhead per frame

**Hotspot Identification:**

- Identify most expensive operations
- Log performance warnings when thresholds exceeded
- Profile with varying unit counts (100, 500, 1000)
- Test with different game speeds

**Performance Logging:**

- Optional performance log mode
- Export timing data for analysis
- Generate performance reports
- Identify regression when code changes

#### Algorithm Optimization

**Data Collection Optimization:**

- Minimize redundant Spring API calls
- Cache static data (unit definitions, team info)
- Batch API calls where possible
- Use more efficient Spring functions if available

**Serialization Optimization:**

- Minimize table creation during serialization
- Reuse buffers and intermediate structures
- Consider lazy serialization (defer until ready to send)
- Profile dkjson performance, consider alternatives if needed

**Transmission Optimization:**

- Combine multiple small packets into larger ones
- Implement Nagle-like algorithm for batching
- Balance latency vs throughput
- Monitor and optimize queue operations

#### Memory Optimization

**Memory Profiling:**

- Track Lua memory usage over time
- Identify memory leaks (unbounded growth)
- Monitor garbage collection frequency
- Test long-running sessions (1+ hours)

**Memory Reduction Strategies:**

- Reuse tables instead of allocating new
- Clear large tables explicitly
- Avoid string concatenation in loops
- Minimize closure creation in hot paths

#### Adaptive Performance Management

**Dynamic Throttling:**

- Monitor actual performance impact
- Reduce collection frequency if frame time spikes
- Reduce data granularity if serialization too slow
- Restore normal rates when performance recovers

**Performance Budget System:**

- Define maximum acceptable overhead (e.g., 2ms/frame)
- Adjust behavior to stay within budget
- Notify user if budget cannot be maintained
- Provide "performance mode" configuration

### 6.3 Edge Case Handling

#### Game State Edge Cases

Handle unusual game conditions:

**Empty/Minimal State:**

- Game just started (no units)
- All units destroyed (end game)
- Single unit remaining
- Zero resources

**Extreme Scale:**

- 1000+ units spawned
- Massive resource values (overflow prevention)
- Very long game duration (counter wrapping)
- Extreme game speed (0.1x or 10x)

**Rapid Changes:**

- Mass unit spawning/destruction
- Rapid game speed changes
- Pause/unpause cycling
- Player switching teams (in some modes)

#### Network Edge Cases

Handle unusual network conditions:

**Connection Scenarios:**

- Server starts before widget
- Server starts after widget
- Server restarts during game
- Multiple connect/disconnect cycles
- Connection never succeeds

**Transmission Issues:**

- Network extremely slow (high latency)
- Network intermittent (packet loss)
- Bandwidth exhausted
- Socket buffer full

**Error Recovery:**

- Corrupted socket state
- Operating system socket limits reached
- Firewall blocking connection mid-stream

#### Widget Lifecycle Edge Cases

Handle BAR-specific scenarios:

**Widget Reload:**

- Widget reloaded during active connection
- Configuration changed during connection
- Multiple reload cycles rapidly

**Game Lifecycle:**

- Widget enabled mid-game
- Game ended while exporting
- Switching between battles
- Loading saved game
- Spectator mode changes

### 6.4 Error Recovery & Resilience

#### Graceful Degradation

Define fallback behaviors:

**Data Collection Degradation:**

- If full collection too expensive, reduce to minimal
- Skip extended data if time budget exceeded
- Prioritize critical data over optional

**Transmission Degradation:**

- If queue backing up, reduce collection frequency
- Drop low-priority data preferentially
- Maintain core game state transmission

**Connection Degradation:**

- Continue queuing data if disconnected (up to limit)
- Preserve most recent data, drop oldest
- Resume transmission on reconnection

#### Recovery Procedures

**Connection Recovery:**

- Clean socket state on disconnect
- Reset retry counters on successful reconnection
- Resend connection metadata on reconnect
- Optionally resend missed data

**State Recovery:**

- Validate widget state on each update
- Detect and correct invalid states
- Log state corruption events
- Reset to safe defaults if unrecoverable

**Data Recovery:**

- Send full snapshot after reconnection
- Resynchronize sequence numbers
- Clear stale queued data
- Indicate data gap to receiver

### 6.5 Comprehensive Testing Strategy

#### Automated Test Suite

Define testable assertions:

**Unit Tests (if framework available):**

- Configuration validation logic
- State machine transitions
- Queue operations
- Serialization of known data structures

**Integration Tests:**

- Full widget lifecycle in BAR
- Connection to mock server
- Data export at various scales
- Performance under load

#### Manual Test Plan

Document human test procedures:

**Functional Testing:**

- Install and enable widget
- Configure connection settings
- Start external test server
- Verify data transmission
- Test all configuration options
- Test console commands

**Performance Testing:**

- Measure FPS with widget enabled vs disabled
- Test with 100, 500, 1000 units
- Run extended game session (1 hour)
- Monitor memory usage
- Verify no performance degradation

**Stress Testing:**

- Rapidly spawn/destroy units
- Connect/disconnect server repeatedly
- Max out unit count
- Run at extreme game speeds
- Pause/unpause rapidly

**Compatibility Testing:**

- Test on Windows
- Test on Linux
- Test with different BAR versions
- Test with other widgets enabled
- Test in multiplayer (as spectator)

#### Regression Testing

Prevent backsliding:

**Test Scenarios Library:**

- Document all test cases
- Record expected outcomes
- Run full suite before releases
- Automate where possible

**Performance Regression:**

- Establish baseline metrics
- Compare against baseline regularly
- Alert on degradation
- Track metrics over time

### 6.6 Code Quality & Documentation

#### Code Review Checklist

Ensure code quality:

**Code Style:**

- Consistent naming conventions
- Proper indentation
- Clear function/variable names
- Logical code organization

**Error Handling:**

- All errors caught and handled
- No silent failures
- Appropriate error messages
- No error propagation to engine

**Performance:**

- No obvious inefficiencies
- Appropriate data structures
- Minimal allocations in hot paths
- Profiling data supports design

#### Inline Documentation

Comprehensive code comments:

**File Header:**

- Widget purpose and overview
- Author and license
- Version history
- Dependencies

**Function Documentation:**

- Purpose and behavior
- Parameters with types
- Return values
- Side effects
- Example usage

**Complex Logic:**

- Explain non-obvious algorithms
- Justify design decisions
- Document gotchas and limitations
- Reference external resources

#### External Documentation

**User Guide (README.md):**

- Installation steps
- Configuration guide
- Usage examples
- Troubleshooting
- FAQ

**Developer Guide (DEVELOPMENT.md):**

- Code architecture overview
- Build/test instructions
- Contribution guidelines
- Roadmap

**API Specification (SCHEMA.md):**

- JSON schema definition
- Message format
- Protocol description
- Example packets
- Client implementation guide

### 6.7 Security Review

#### Security Considerations

Review potential vulnerabilities:

**Network Security:**

- Default to localhost connection
- Warn about remote connections in documentation
- No authentication in MVP (document limitation)
- No encryption in MVP (document limitation)

**Data Privacy:**

- Verify only local player data exported
- Respect fog of war
- No sensitive personal data exposed
- Document data collected

**Input Validation:**

- Validate all configuration inputs
- Sanitize user-provided strings
- Prevent injection attacks in logging
- Bounds checking on numeric inputs

#### Ethical Considerations

Ensure fair play:

**Multiplayer Impact:**

- Widget provides no gameplay advantage
- Only exports visible information
- Equivalent to observer viewing screen
- Document intended use cases

**Performance Impact:**

- Does not degrade other players' experience
- Minimal network usage
- No server load

### 6.8 Release Preparation

#### Version Management

Establish versioning scheme:

**Semantic Versioning:**

- Format: MAJOR.MINOR.PATCH (e.g., 1.0.0)
- Increment MAJOR for breaking changes
- Increment MINOR for new features
- Increment PATCH for bug fixes

**Version Documentation:**

- Maintain CHANGELOG.md
- Document all changes between versions
- Note breaking changes prominently
- Provide migration guide

#### Release Checklist

Final pre-release verification:

**Code Checklist:**

- [ ] All phases implemented and tested
- [ ] No known critical bugs
- [ ] Performance meets benchmarks
- [ ] Memory stable over extended use
- [ ] All configuration options functional

**Documentation Checklist:**

- [ ] README complete and accurate
- [ ] API specification finalized
- [ ] Code comments comprehensive
- [ ] License file included
- [ ] Example integration provided

**Testing Checklist:**

- [ ] All manual tests passed
- [ ] Performance benchmarks met
- [ ] Edge cases handled
- [ ] Multiple platform testing
- [ ] Extended runtime testing (1+ hour)

**Community Checklist:**

- [ ] Demo video prepared
- [ ] Forum post drafted
- [ ] Example external tool available
- [ ] Support channels established

### 6.9 Deliverables for Phase 5

**Production-Ready Widget:**

- Optimized for performance
- Comprehensive error handling
- Thorough documentation
- Tested extensively
- Ready for community release

**Supporting Materials:**

- Complete user documentation
- Developer integration guide
- Example external tool implementation
- Test suite and procedures

**Quality Benchmarks:**

- <2ms average overhead with 500 units
- Zero crashes in 1-hour test session
- Memory stable over extended use
- Handles all documented edge cases
- Documentation sufficient for independent integration

---

## 7. Post-MVP+ Enhancements (Future Phases)

### 7.1 Potential Future Features

Features beyond MVP+ scope:

**Bidirectional Communication:**

- Receive commands from external tool
- Remote control capabilities
- Configuration changes from external source

**Advanced Data Export:**

- Video frame capture and streaming
- Audio analysis and export
- Detailed projectile tracking
- Pathfinding visualization data

**Protocol Enhancements:**

- WebSocket support for browser clients
- Binary protocol (more efficient than JSON)
- Compression (gzip, msgpack)
- Authentication and encryption

**Multi-Client Support:**

- Broadcast to multiple consumers simultaneously
- Client subscription to data subsets
- Priority-based client handling

**External Tool Ecosystem:**

- Reference implementation in Python/Node.js
- Live statistics dashboard
- Twitch/YouTube overlay integration
- Machine learning dataset generation
- Replay enhancement tools

### 7.2 Community Feedback Integration

Plan for iterative improvement:

**Feedback Channels:**

- BAR Discord discussion thread
- GitHub issues tracker
- Community forum thread
- User surveys

**Feature Requests:**

- Prioritize based on user demand
- Evaluate technical feasibility
- Consider performance impact
- Maintain backward compatibility

---

## 8. Implementation Guidelines for AI Coding Agents

### 8.1 General Instructions

**Code Style:**

- Follow Lua community conventions
- Use clear, descriptive variable names
- Keep functions focused and concise
- Comment complex logic thoroughly

**Error Handling:**

- Assume all external calls can fail
- Handle errors gracefully without crashes
- Log errors with sufficient context
- Never let errors propagate to engine

**Performance:**

- Profile before optimizing
- Document performance-critical sections
- Set performance budgets for operations
- Test with realistic data scales

**Testing:**

- Test each phase independently before proceeding
- Verify integration after combining phases
- Document test procedures for humans
- Create reproducible test scenarios

### 8.2 Phase Implementation Order

**Strict Dependencies:**

- Phase 1 must complete before Phase 2
- Phase 2 must complete before Phase 3
- Phase 3 must complete before Phase 4
- Phase 5 refines all previous phases

**Incremental Development:**

- Commit after each phase completion
- Tag stable milestones
- Maintain working version at all times
- Avoid breaking existing functionality

### 8.3 Common Pitfalls to Avoid

**Network Programming:**

- Never use blocking socket calls
- Always check socket operation return values
- Expect disconnections at any time
- Handle partial sends correctly

**Lua Specifics:**

- Tables are 1-indexed, not 0-indexed
- String concatenation in loops creates garbage
- Closures capture by reference
- Metatables affect table behavior

**BAR Integration:**

- Widget:Initialize() must return true or false
- Spring.Echo() is for user messages, not debugging
- VFS is read-only for most widgets
- Widget can be disabled by user at any time

### 8.4 Success Validation

**After Each Phase:**

- Widget loads without errors
- New functionality works as specified
- No regression in previous functionality
- Performance remains acceptable
- Documentation updated

**Before Final Release:**

- All test procedures passed
- All documentation complete
- Performance benchmarks met
- No known critical issues
- Community-ready presentation prepared

---

## 9. Support & Maintenance Plan

### 9.1 Support Channels

**User Support:**

- BAR Discord channel
- GitHub discussions
- FAQ documentation
- Video tutorials

**Developer Support:**

- API documentation
- Integration examples
- Code comments
- Architecture diagrams

### 9.2 Maintenance Responsibilities

**Bug Fixes:**

- Respond to reported issues
- Prioritize by severity
- Release patches promptly
- Document fixes in changelog

**Compatibility Updates:**

- Monitor BAR/Recoil engine updates
- Test with new engine versions
- Update deprecated API usage
- Maintain backward compatibility where possible

**Feature Evolution:**

- Consider community requests
- Plan major versions
- Communicate roadmap
- Maintain stable branch

---

## 10. Document Control

**Document Version:** 1.0  
**Created:** 2025-01-28  
**Status:** Ready for Implementation  
**Target Audience:** AI Coding Agents (Claude Code, etc.)  
**Related Documents:** Research & Architecture Planning Document

**Change History:**

- v1.0 (2025-01-28): Initial implementation specification

---

## Conclusion

This implementation specification provides comprehensive guidance for developing the Live Data Export Widget in a structured, phase-based approach. Each phase builds upon previous work, ensuring a solid foundation and manageable complexity. The MVP+ includes not just basic functionality, but also the polish and robustness required for production use.

AI coding agents should implement each phase sequentially, validating completion before proceeding. The specification intentionally avoids prescriptive code solutions, instead providing requirements, constraints, and design guidance that allows the coding agent to make appropriate implementation decisions within established parameters.

The result will be a production-ready widget that enables the Beyond All Reason community to build innovative tools, overlays, and analytics platforms powered by live game data.