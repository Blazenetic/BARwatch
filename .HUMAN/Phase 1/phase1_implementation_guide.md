# Phase 1 Implementation Guide: Socket Infrastructure
## BAR Live Data Export Widget - AI Code Bot Instructions

---

## Overview

You are implementing Phase 1 of a Lua widget for Beyond All Reason (BAR) that will export real-time game data via TCP sockets. This phase focuses solely on establishing robust socket infrastructure - the foundation that all other phases will build upon.

### Phase 1 Goal
Create a reliable, non-blocking TCP client that can connect to external servers, maintain stable connections, and gracefully handle network issues without impacting game performance.

---

## Context and Constraints

### Environment
- **Platform**: Beyond All Reason game client (Recoil Engine)
- **Lua Version**: 5.1/5.2 (verify with `_VERSION`)
- **Widget Type**: Unsynced widget (runs locally, not synchronized across network)
- **Available Libraries**: LuaSocket (confirmed available in BAR)
- **Execution Context**: Single-threaded, must never block the game loop

### Critical Requirements
1. **Non-blocking Operations**: Every socket operation must be non-blocking. A blocking call will freeze the entire game.
2. **Performance Budget**: Total execution time must stay under 2ms per frame
3. **Graceful Failures**: Network issues must not crash the widget or game
4. **State Management**: Maintain clear connection states for debugging and recovery

---

## Implementation Components

### 1. Widget Structure

Create a standard BAR widget with proper metadata and lifecycle functions:

**Required Widget Info**:
- Name: "Live Data Export"
- Description: Clear explanation of the widget's purpose
- Author: Your identifier
- Version: Start with "1.0.0"
- Date: Current date
- License: GPL v2 (standard for BAR widgets)
- Layer: Use a low layer number (e.g., -10) to avoid conflicts
- Enabled: Default to true

**Essential Widget Functions**:
- `widget:Initialize()` - Setup initial state and configuration
- `widget:Shutdown()` - Clean disconnection and resource cleanup
- `widget:Update()` or `widget:GameFrame()` - Main update loop for socket operations
- `widget:GetConfigData()` - Save configuration between sessions
- `widget:SetConfigData()` - Load saved configuration

### 2. Socket Management Module

**Core Responsibilities**:
- Create TCP client socket using LuaSocket
- Configure socket for non-blocking mode immediately after creation
- Implement connection state machine
- Handle socket lifecycle (create, connect, disconnect, cleanup)

**State Machine Design**:
Define clear states and transitions:
- `DISCONNECTED`: Initial state, no socket exists
- `CONNECTING`: Socket created, connection attempt in progress
- `CONNECTED`: Successfully connected and ready for data
- `RECONNECTING`: Connection lost, waiting before retry attempt
- `ERROR`: Recoverable error state with retry capability

**Connection Configuration**:
- Default host: "localhost" or "127.0.0.1"
- Default port: 9876 (or another unused high port)
- Make these configurable but provide sensible defaults

### 3. Non-Blocking Operations

**Critical Implementation Points**:
- Set socket timeout to 0 immediately after creation
- Use `settimeout(0)` to ensure non-blocking mode
- Check socket:connect() return values carefully:
  - Success: Connection established immediately (rare)
  - "timeout": Connection in progress (expected for non-blocking)
  - Other errors: Actual connection failures

**Polling Pattern**:
In the update loop:
1. Check current state
2. Perform appropriate action (connect attempt, status check, etc.)
3. Handle results without blocking
4. Update state if needed
5. Return quickly

### 4. Reconnection Logic

**Exponential Backoff Strategy**:
- Initial retry delay: 1 second
- Maximum retry delay: 30 seconds
- Backoff multiplier: 2x
- Reset delay on successful connection

**Implementation Approach**:
- Track last connection attempt time
- Calculate next allowed attempt time
- Only attempt reconnection when enough time has passed
- Increment delay after each failure
- Provide user feedback about reconnection attempts

### 5. Error Handling

**Socket Errors to Handle**:
- Connection refused (server not running)
- Connection timeout (network issues)
- Connection reset (server disconnected)
- Socket creation failure (system resource issues)

**Error Response Strategy**:
- Log errors clearly but don't spam the console
- Transition to appropriate state
- Schedule reconnection if appropriate
- Never let errors propagate to crash the widget

### 6. Logging and Diagnostics

**Logging Requirements**:
- Use Spring.Echo() for user-visible messages
- Prefix all messages with widget name for clarity
- Log state transitions for debugging
- Include timestamps for connection events
- Provide different verbosity levels (configurable)

**Diagnostic Information**:
- Current connection state
- Time since last successful connection
- Number of reconnection attempts
- Current retry delay
- Last error message

### 7. Configuration System

**User-Configurable Options**:
- Server host/IP address
- Server port number
- Auto-reconnect enabled/disabled
- Reconnection delay settings
- Logging verbosity level
- Widget enabled/disabled state

**Configuration Storage**:
- Use widget's GetConfigData/SetConfigData functions
- Store as Lua table
- Provide defaults for missing values
- Validate configuration on load

### 8. User Interface Elements

**Minimal UI for Phase 1**:
- Status indicator (text or simple graphic)
- Show current connection state
- Display last error if relevant
- Basic connect/disconnect command

**Console Commands**:
Consider implementing:
- `/livedata connect` - Manual connection
- `/livedata disconnect` - Manual disconnection  
- `/livedata status` - Show current state
- `/livedata sethost <host>` - Configure server
- `/livedata setport <port>` - Configure port

---

## Testing Guidance

### Test Scenarios

1. **Basic Connection**:
   - Start external TCP server first
   - Load widget
   - Verify successful connection
   - Check status indicators

2. **Server Not Running**:
   - Load widget without server
   - Verify graceful failure
   - Start server
   - Verify automatic reconnection

3. **Connection Loss**:
   - Establish connection
   - Stop server
   - Verify detection and reconnection attempts
   - Restart server
   - Verify successful reconnection

4. **Performance Testing**:
   - Monitor frame rate with widget active
   - Ensure no frame drops during connection attempts
   - Verify sub-2ms execution time

### External Test Server

Create a simple Python or Node.js TCP server for testing:
- Listen on configured port
- Accept connections
- Log connection events
- Keep connection alive
- Allow controlled disconnection for testing

---

## Code Quality Guidelines

### Structure
- Organize code into logical sections with clear comments
- Separate concerns (socket management, state machine, configuration)
- Use descriptive variable and function names
- Maintain consistent indentation and formatting

### Best Practices
- Initialize all variables explicitly
- Check for nil values before operations
- Use local variables whenever possible (Lua performance)
- Avoid global namespace pollution
- Clean up resources properly on shutdown

### Documentation
- Comment complex logic thoroughly
- Document state transitions
- Explain non-obvious design decisions
- Include usage examples in comments

---

## Common Pitfalls to Avoid

1. **Blocking Operations**: Never use blocking socket calls
2. **Infinite Loops**: Ensure all loops have exit conditions
3. **Resource Leaks**: Always close sockets properly
4. **Error Cascades**: Prevent errors from triggering more errors
5. **Console Spam**: Limit error message frequency
6. **State Confusion**: Maintain single source of truth for connection state

---

## Success Criteria for Phase 1

Your implementation is complete when:

1. Widget loads successfully in BAR without errors
2. Can establish TCP connection to external server
3. Maintains stable connection during gameplay
4. Automatically reconnects after connection loss
5. All operations are non-blocking
6. Performance overhead is under 2ms per frame
7. Clean shutdown without resource leaks
8. Clear status feedback to user
9. Configuration persists between sessions
10. Comprehensive error handling prevents crashes

---

## Next Steps After Phase 1

Once Phase 1 is stable:
- Test thoroughly with various network conditions
- Gather performance metrics
- Document any limitations discovered
- Prepare socket infrastructure for Phase 2 (data transmission)
- Ensure the foundation is solid before building upon it

---

## Additional Notes

- Start simple and iterate - get basic connection working first
- Test frequently during development
- Use version control to track changes
- Consider edge cases early in development
- The socket infrastructure is critical - take time to get it right
- This phase sets the pattern for all subsequent development

Remember: Phase 1 is purely about establishing reliable socket communication. Don't attempt to send game data yet - that comes in Phase 2. Focus on creating a rock-solid foundation that won't impact game performance.
