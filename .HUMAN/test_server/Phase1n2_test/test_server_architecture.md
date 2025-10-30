# Test Server Architecture Design for BAR Live Data Export Widget

## Overview

Enhanced test server architecture to validate Phase 1 (socket infrastructure) and Phase 2 (data collection) implementations with clear, actionable test results and minimal log noise.

---

## Design Principles

1. **Signal-to-Noise Optimization**: Only display meaningful events and test results
2. **Progressive Validation**: Test each phase's capabilities systematically
3. **Visual Clarity**: Use structured output with clear pass/fail indicators
4. **Real-time Monitoring**: Live statistics dashboard without spam
5. **Debugging on Demand**: Verbose logging available but off by default

---

## Architecture Components

### 1. Connection Monitor
**Purpose**: Validate Phase 1 socket infrastructure

**Metrics Tracked**:
- Connection establishment time
- Reconnection attempts and success rate
- Connection stability (uptime, disconnects)
- Socket state transitions

**Output Format**:
```
[CONNECTION] Widget connected from 127.0.0.1:54321 (42ms)
[CONNECTION] Stable for 5m 23s | Reconnects: 0
```

### 2. Data Validator
**Purpose**: Verify Phase 2 data collection accuracy

**Validation Checks**:
- Schema version compatibility
- Required field presence
- Data type correctness
- Value range sanity checks
- Timestamp consistency

**Output Format**:
```
[VALIDATION] âœ" Schema v1.0 | âœ" All required fields | âœ" Type checks passed
[VALIDATION] âœ— Warning: 3 units with invalid positions
```

### 3. Statistics Dashboard
**Purpose**: Real-time performance and data quality monitoring

**Displays**:
- Packets received (total, rate)
- Data collection frequency
- Unit count statistics
- Performance metrics (widget overhead)
- Data completeness percentage

**Update Frequency**: Every 5 seconds or configurable interval

**Output Format**:
```
╔══════════════════════════════════════════════════════════════╗
║               BAR Widget Test Dashboard                      ║
╠══════════════════════════════════════════════════════════════╣
║ Connection: STABLE (8m 42s)          Packets: 1,547         ║
║ Data Rate:  3.0 Hz                   Errors:  0              ║
║ Units:      287 avg (min: 12, max: 512)                      ║
║ Performance: 0.8ms avg (Phase 1: 0.1ms, Phase 2: 0.7ms)     ║
║ Completeness: 100% (all expected fields present)             ║
╚══════════════════════════════════════════════════════════════╝
```

### 4. Test Suite Runner
**Purpose**: Automated validation of widget functionality

**Test Categories**:

**Phase 1 Tests**:
- Connection establishment
- Reconnection after disconnect
- Non-blocking behavior validation
- State machine transitions
- Error recovery

**Phase 2 Tests**:
- Data collection frequency
- Field completeness
- Fog of war compliance
- Performance benchmarks
- Data consistency

**Output Format**:
```
[TEST SUITE] Running Phase 1 Tests...
  âœ" Connection established within 5s threshold
  âœ" Reconnection after simulated disconnect (2.1s)
  âœ" Non-blocking confirmed (no timeout errors)
  âœ" State transitions: DISCONNECTED → CONNECTING → CONNECTED
  
[TEST SUITE] Running Phase 2 Tests...
  âœ" Data collection at 3.0 Hz (target: 3 Hz)
  âœ" All required fields present in 150/150 packets
  âœ" Unit visibility checks passed
  âœ" Performance: 0.9ms avg (target: <2ms)
  
[RESULTS] 9/9 tests passed (100%)
```

### 5. Event Logger
**Purpose**: Capture significant events without spam

**Log Levels**:
- `CRITICAL`: Connection failures, crashes
- `ERROR`: Validation failures, malformed data
- `WARNING`: Performance degradation, missing optional fields
- `INFO`: Major milestones (default level)
- `DEBUG`: Detailed packet contents (off by default)

**Smart Filtering**:
- Deduplicate repeated errors (show count instead)
- Suppress routine events (packet received)
- Highlight anomalies

**Output Format**:
```
[INFO] 15:42:31 - Widget connected successfully
[WARNING] 15:43:02 - High unit count (534) may impact performance
[ERROR] 15:43:15 - Schema validation failed (x3 in last minute)
```

### 6. Interactive Command Interface
**Purpose**: Control test server behavior during runtime

**Commands**:
- `status` - Show current dashboard
- `test` - Run full test suite
- `test phase1` / `test phase2` - Run specific phase tests
- `validate` - Manually validate last packet
- `disconnect` - Simulate disconnect for reconnection test
- `stats` - Show detailed statistics
- `log [level]` - Change logging verbosity
- `dump` - Show last received packet (JSON)
- `clear` - Clear console
- `help` - Show command list

---

## Data Flow Architecture

```
┌─────────────────┐
│   BAR Widget    │
│  (Lua Client)   │
└────────┬────────┘
         │ TCP Connection
         │
┌────────▼────────────────────────────────────────────────┐
│                   Test Server                           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐      ┌─────────────┐                 │
│  │ Connection   │──────▶│  Event      │                 │
│  │ Monitor      │      │  Logger     │                 │
│  └──────────────┘      └─────────────┘                 │
│         │                                                │
│         ▼                                                │
│  ┌──────────────┐      ┌─────────────┐                 │
│  │ Packet       │──────▶│ Statistics  │                 │
│  │ Receiver     │      │ Dashboard   │                 │
│  └──────┬───────┘      └─────────────┘                 │
│         │                     ▲                          │
│         ▼                     │                          │
│  ┌──────────────┐            │                          │
│  │ Data         │────────────┘                          │
│  │ Validator    │                                       │
│  └──────┬───────┘                                       │
│         │                                                │
│         ▼                                                │
│  ┌──────────────┐      ┌─────────────┐                 │
│  │ Test Suite   │──────▶│  Results    │                 │
│  │ Runner       │      │  Reporter   │                 │
│  └──────────────┘      └─────────────┘                 │
│                                                          │
│         ▲                                                │
│         │                                                │
│  ┌──────┴───────┐                                       │
│  │ Interactive  │                                       │
│  │ CLI          │                                       │
│  └──────────────┘                                       │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## Configuration System

### Default Settings
```python
CONFIG = {
    'host': '127.0.0.1',
    'port': 9876,
    'log_level': 'INFO',
    'dashboard_update_interval': 5,  # seconds
    'auto_test': False,  # Run tests on connection
    'save_packets': False,  # Save to file for analysis
    'max_packet_history': 100,
    'validation_strict': False,  # Fail on warnings
}
```

### Runtime Configuration
- Adjustable via command line arguments
- Interactive commands to modify during runtime
- Configuration file support (JSON/YAML)

---

## Output Examples

### Startup
```
╔══════════════════════════════════════════════════════════════╗
║        BAR Live Data Export Widget - Test Server            ║
║                    Phase 1 & 2 Validation                    ║
╚══════════════════════════════════════════════════════════════╝

[INFO] Server listening on 127.0.0.1:9876
[INFO] Log level: INFO (use 'log debug' for verbose output)
[INFO] Dashboard updates every 5s
[INFO] Waiting for BAR widget connection...

Type 'help' for available commands
>
```

### Normal Operation (Quiet Mode)
```
[CONNECTION] Widget connected (38ms)
[VALIDATION] Initial packet validated successfully

> status
╔══════════════════════════════════════════════════════════════╗
║               BAR Widget Test Dashboard                      ║
╠══════════════════════════════════════════════════════════════╣
║ Connection: STABLE (2m 15s)          Packets: 405           ║
║ Data Rate:  3.0 Hz                   Errors:  0              ║
║ Units:      142 avg (min: 89, max: 203)                      ║
║ Performance: 1.1ms avg (Phase 1: 0.1ms, Phase 2: 1.0ms)     ║
║ Completeness: 100% (all expected fields present)             ║
╚══════════════════════════════════════════════════════════════╝
```

### Test Results
```
> test

[TEST SUITE] Starting comprehensive validation...

Phase 1: Socket Infrastructure
  âœ" Connection establishment: 42ms (threshold: 5000ms)
  âœ" Non-blocking I/O: Confirmed
  âœ" Reconnection logic: Success in 2.1s after disconnect
  âœ" State machine: All transitions valid
  âœ" Resource cleanup: No leaks detected

Phase 2: Data Collection
  âœ" Collection frequency: 3.0 Hz (target: 3.0 Hz, tolerance: ±0.5Hz)
  âœ" Schema validation: 100% (150/150 packets)
  âœ" Required fields: âœ" game_frame âœ" game_seconds âœ" teams âœ" units
  âœ" Unit data quality: Position, health, team ID all valid
  âœ" Performance: 0.9ms avg, 1.8ms max (threshold: 2ms)
  âœ— Fog of war: SKIP (requires multiplayer test)

Integration Tests
  âœ" End-to-end latency: 3ms avg
  âœ" Data consistency: Timestamps monotonic, no gaps
  âœ" Memory stability: No growth detected (5min test)

╔══════════════════════════════════════════════════════════════╗
║                       TEST RESULTS                           ║
╠══════════════════════════════════════════════════════════════╣
║  Passed:  13/14  (92.9%)                                     ║
║  Failed:  0/14                                               ║
║  Skipped: 1/14                                               ║
║                                                              ║
║  Status: âœ" PHASE 1 & 2 VALIDATED - Ready for Phase 3       ║
╚══════════════════════════════════════════════════════════════╝
```

---

## File Structure

```
test_server/
├── server.py                 # Main server entry point
├── connection_monitor.py     # Phase 1 validation
├── data_validator.py         # Phase 2 validation
├── statistics.py             # Metrics tracking
├── test_suite.py             # Automated tests
├── dashboard.py              # Display formatting
├── logger.py                 # Event logging
├── cli.py                    # Interactive commands
├── config.py                 # Configuration management
└── utils.py                  # Helper functions
```

---

## Key Features

### Anti-Spam Measures
1. **Dashboard replaces live updates** - No scrolling spam
2. **Error deduplication** - "Connection lost (x5)" instead of 5 lines
3. **Configurable verbosity** - INFO by default, DEBUG on demand
4. **Smart event filtering** - Only significant state changes logged
5. **Periodic summaries** - Aggregate stats instead of per-packet logs

### Developer Experience
1. **Clear pass/fail indicators** - âœ" âœ— symbols
2. **Color coding** - Green (success), Red (error), Yellow (warning)
3. **Progress indicators** - For long-running tests
4. **Export results** - Save test reports to file
5. **Copy-paste friendly** - Structured output for bug reports

### Extensibility
1. **Plugin architecture** - Easy to add new validators
2. **Custom test definitions** - JSON/YAML test specifications
3. **Webhooks** - Notify external systems of test results
4. **Metrics export** - Prometheus/Grafana integration ready

---

## Success Criteria

### Phase 1 Validation
- âœ" Connection established within 5 seconds
- âœ" Reconnection works after disconnect
- âœ" No blocking detected (game continues smoothly)
- âœ" State transitions follow expected sequence
- âœ" Performance overhead <0.5ms

### Phase 2 Validation
- âœ" Data collection at configured frequency (±0.5 Hz)
- âœ" All required schema fields present
- âœ" Data types match specification
- âœ" Unit counts reasonable (0-10000 range)
- âœ" Performance overhead <2ms total
- âœ" No memory leaks over 10+ minute session

### Overall Quality
- âœ" Zero crashes during testing
- âœ" Clear test results within 30 seconds
- âœ" Console readable without scrolling back
- âœ" Easy to identify failures and causes

---

## Implementation Priority

### High Priority (Core Functionality)
1. Enhanced packet receiver with validation
2. Statistics dashboard with live updates
3. Basic test suite (Phase 1 & 2)
4. Connection monitoring with metrics
5. Interactive CLI with essential commands

### Medium Priority (Quality of Life)
6. Event logger with smart filtering
7. Detailed validation reports
8. Configuration system
9. Export functionality

### Low Priority (Advanced Features)
10. Performance profiling tools
11. Historical data analysis
12. Webhook integrations
13. Custom test definitions

---

This architecture provides a robust, developer-friendly test environment that validates widget functionality without overwhelming the console, making it easy to identify issues and confirm that Phases 1 and 2 are working correctly before proceeding to Phase 3.