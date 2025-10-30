# Beyond All Reason Live Data Export Widget - Project Proposal

## Executive Summary

This project develops a Lua widget for Beyond All Reason (BAR) that exports real-time game state data via TCP sockets to external applications. This enables developers to create live overlays, statistics dashboards, streaming tools, and analytics platforms that enhance the player and spectator experience.

---

## Project Overview

### What We're Building

A lightweight, high-performance Lua widget that:

- Runs inside the BAR game client
- Collects live game state data (units, resources, game time, etc.)
- Serializes data to JSON format
- Transmits via TCP socket to external tools
- Operates without impacting game performance

### Why It's Needed

Currently, external tools can only analyze BAR matches through post-game replay files. This widget bridges BAR with external applications in real-time, enabling:

- Live statistics overlays for streamers
- Real-time match analytics dashboards
- Automated coaching tools
- Data collection for machine learning research
- Live spectator enhancements

### Target Users

- **Streamers/Content Creators**: Overlay real-time statistics on broadcasts
- **Tournament Organizers**: Display live match data for viewers
- **Data Scientists**: Collect gameplay data for analysis
- **Tool Developers**: Build applications that interact with live games
- **Competitive Players**: Analyze gameplay patterns in real-time

---

## Technical Architecture

### Technology Stack

- **Platform**: Beyond All Reason (Recoil Engine)
- **Language**: Lua 5.1/5.2
- **Networking**: LuaSocket (TCP, non-blocking I/O)
- **Serialization**: dkjson (JSON encoding)
- **Integration**: BAR widget system

### Core Components

**1. Socket Management Layer**

- Non-blocking TCP client connection
- Automatic reconnection with exponential backoff
- Connection state machine (disconnected, connecting, connected, reconnecting)
- Graceful error handling

**2. Data Collection Module**

- Hooks into BAR's game simulation loop (30 Hz updates)
- Accesses game state via Spring engine API
- Collects: unit positions/health, player resources, game time, team data
- Respects fog of war (only exports visible data)

**3. Serialization Pipeline**

- Structures data into JSON schema
- Configurable granularity (minimal, standard, comprehensive)
- Performance-optimized encoding
- Transmission queue with overflow protection

**4. Configuration System**

- User-configurable connection settings (host, port)
- Adjustable export frequency and data detail level
- Persistent configuration across sessions
- Console commands and GUI options

### Data Flow

```
BAR Game State → Data Collection → JSON Serialization → Queue → TCP Socket → External Tool
     ↑                                                                            ↓
     └──────────────── Connection Management ←───────────────────────────────────┘
```

---

## Key Features

### MVP+ Functionality

- **Stable Network Communication**: Reliable TCP connection with automatic recovery
- **Real-Time Data Export**: Game state updates at 30 Hz (configurable)
- **Performance Optimized**: <2ms overhead per frame with 500+ units
- **Configurable Output**: Adjustable data granularity and frequency
- **User-Friendly**: Clear status feedback and easy configuration
- **Production-Ready**: Comprehensive error handling and edge case management

### Data Schema Example

```json
{
  "schema_version": "1.0",
  "game_frame": 9000,
  "game_seconds": 300.0,
  "is_paused": false,
  "teams": [
    {
      "team_id": 0,
      "metal": {"current": 500, "income": 10},
      "energy": {"current": 3000, "income": 50}
    }
  ],
  "units": [
    {
      "id": 42,
      "def_id": 15,
      "team": 0,
      "pos": {"x": 1024, "y": 50, "z": 2048},
      "health": {"current": 850, "max": 1000}
    }
  ]
}
```

---

## Implementation Approach

### Phase-Based Development

**Phase 1: Foundation** (Socket Infrastructure)

- TCP socket connection management
- Non-blocking I/O implementation
- State machine and retry logic
- Basic logging and diagnostics

**Phase 2: Data Collection** (Game State Access)

- Spring API integration
- Data collection scheduling
- Schema design and structure
- Performance optimization

**Phase 3: Transmission** (JSON Pipeline)

- dkjson integration
- Serialization optimization
- Transmission queue
- Message framing protocol

**Phase 4: User Experience** (Configuration & Feedback)

- Configuration system
- Status feedback mechanisms
- Documentation
- Console commands

**Phase 5: Production Polish** (Optimization & Testing)

- Performance profiling
- Edge case handling
- Comprehensive testing
- Final documentation

### Development Principles

- **Non-Blocking**: All operations must avoid blocking the game loop
- **Performance-First**: Target <2ms total overhead per frame
- **Graceful Degradation**: Handle failures without crashing
- **User-Centric**: Clear feedback and easy configuration
- **Well-Documented**: Code comments and user guides

---

## Technical Constraints

### BAR/Recoil Engine Limitations

- **Single-threaded Lua**: No parallel processing available
- **Non-blocking Required**: Blocking operations freeze game
- **Sandbox Restrictions**: No filesystem access, limited OS interaction
- **Widget Context**: Unsynced only (local player perspective)
- **Network Access**: TCP allowed, UDP restricted

### Performance Requirements

- Maximum 2ms execution time per frame (33 FPS target = 30ms frame budget)
- Stable memory usage over extended sessions
- No frame drops with 500+ units
- Minimal CPU overhead

### Data Privacy & Fair Play

- Widget only exports data visible to local player
- Respects fog of war in multiplayer
- No gameplay advantage provided
- Spectator mode grants full visibility (intended use case)

---

## Use Case Examples

### Live Streaming Overlay

**Scenario**: Streamer wants to display real-time army value and resource graphs **Solution**: External tool receives game data, renders overlay via OBS browser source

### Tournament Broadcast

**Scenario**: Caster wants to show detailed unit composition during match **Solution**: Widget exports unit data, external dashboard visualizes statistics

### Gameplay Analysis

**Scenario**: Player wants to review resource efficiency after match **Solution**: Tool records live data stream, generates post-game analytics report

### Machine Learning Research

**Scenario**: Researcher needs large dataset of gameplay decisions **Solution**: Widget exports decision points (orders, builds) to database

---

## Success Metrics

### Technical Metrics

- Widget loads without errors in BAR
- Establishes connection within 5 seconds
- Maintains 30 packets/second transmission rate
- Handles 500+ units with <2ms overhead
- Zero crashes in 1-hour test session

### User Metrics

- Configuration takes <5 minutes
- Clear connection status feedback
- Graceful failure recovery
- Comprehensive troubleshooting documentation

### Community Metrics

- Reference implementation for external tools available
- At least 3 example use cases documented
- API specification complete for third-party developers
- Active adoption by content creators/developers

---

## Project Status & Next Steps

### Current Status

**Planning Phase Complete** - Architecture and implementation specifications finalized

### Immediate Next Steps

1. Implement Phase 1 (Socket Infrastructure)
2. Create external test server (Python/Node.js)
3. Validate connection management
4. Proceed to Phase 2 (Data Collection)

### Estimated Scope

- **Core Implementation**: 5 phases as detailed in specification
- **Testing & Documentation**: Throughout all phases
- **Community Release**: After Phase 5 completion

---

## Technical Support Resources

### Documentation Provided

- **Research Document**: Comprehensive analysis of BAR/Recoil capabilities
- **Implementation Specification**: Detailed phase-by-phase development guide
- **This Proposal**: High-level project overview

### Key References

- BAR GitHub: https://github.com/beyond-all-reason/Beyond-All-Reason
- Recoil Engine: https://github.com/beyond-all-reason/RecoilEngine
- Lua API Docs: https://beyond-all-reason.github.io/RecoilEngine/docs/lua-api/
- LuaSocket: http://w3.impa.br/~diego/software/luasocket/
- dkjson: http://dkolf.de/dkjson-lua/

### Support Channels

- BAR Discord (for community feedback)
- GitHub Issues (for bug tracking)
- Documentation (README, API spec)

---

## Deliverables

### Code

- `export_livedata.lua` - Main widget file
- Embedded or bundled dkjson library
- Configuration templates

### Documentation

- `README.md` - User installation and configuration guide
- `SCHEMA.md` - JSON API specification for external developers
- `DEVELOPMENT.md` - Code architecture and contribution guide
- Inline code comments throughout

### Examples

- Python TCP server for receiving data
- Example data visualization tool
- Integration guide for common use cases

---

## Risk Mitigation

### Technical Risks

|Risk|Mitigation|
|---|---|
|Performance impact on game|Strict performance budgets, adaptive throttling|
|Network instability|Queue buffering, automatic reconnection|
|Engine API changes|Version checking, compatibility layer|

---

## Conclusion

The BAR Live Data Export Widget fills a critical gap in the BAR ecosystem by enabling real-time integration with external tools. The project is technically feasible within BAR's architecture, follows established best practices for widget development, and addresses genuine community needs for streaming, analytics, and tool development.

The phased implementation approach ensures manageable complexity, thorough testing, and production-ready quality. Success will be measured by technical performance, ease of use, and community adoption for building innovative BAR-powered applications.