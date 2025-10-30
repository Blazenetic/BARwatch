# Phase 3 Implementation Guide: JSON Serialization & Transmission
## BAR Live Data Export Widget - AI Code Bot Instructions

---

## Overview

You are implementing Phase 3 of the BAR Live Data Export Widget. With Phase 1's socket infrastructure and Phase 2's data collection complete, Phase 3 focuses on serializing the collected game state data to JSON format and transmitting it efficiently through the established socket connection.

### Phase 3 Goal
Create an efficient JSON serialization pipeline that converts game state data into well-structured JSON messages, implements a transmission queue with overflow protection, and ensures reliable delivery to external applications while maintaining performance.

---

## Prerequisites

### Required from Previous Phases

**From Phase 1**:
- Working TCP socket connection
- Non-blocking socket operations
- Connection state management
- Error handling framework
- Reconnection logic

**From Phase 2**:
- Game state data collection
- Structured data organization
- Configurable update frequencies
- Performance monitoring
- Data validation

### New Requirements for Phase 3
- JSON encoding using dkjson library
- Message framing protocol
- Queue management
- Transmission scheduling
- Performance optimization for serialization
- Message size management

---

## Context and Constraints

### Technical Constraints
- **JSON Library**: dkjson (pure Lua implementation)
- **Message Size**: TCP has no built-in message boundaries
- **Performance Budget**: Combined with Phases 1-2, stay under 2ms
- **Memory Usage**: Minimize allocations during serialization
- **Network Bandwidth**: Consider message frequency vs size
- **Socket Buffer**: Limited OS-level socket buffer size

### Serialization Principles
1. **Efficient Encoding**: Minimize JSON string size where possible
2. **Message Framing**: Clear message boundaries for parsing
3. **Queue Management**: Handle backpressure gracefully
4. **Error Resilience**: Don't lose data on temporary failures
5. **Performance Priority**: Game performance over data completeness

---

## Implementation Components

### 1. dkjson Integration

**Library Setup**:
- Include dkjson library in widget (embedded or separate file)
- Verify compatibility with BAR's Lua version
- Configure encoding options for optimal performance
- Handle library loading errors gracefully

**dkjson Configuration**:
```lua
-- Suggested configuration approach
encode_options = {
    indent = false,  -- No pretty printing for size
    keyorder = nil,  -- No key sorting overhead
    level = 1,       -- Start level for recursion
    null = nil,      -- How to represent null values
}
```

**Performance Considerations**:
- dkjson is pure Lua (no C speedups)
- Pre-configure options to avoid repeated setup
- Consider caching encoder function reference
- Be aware of table depth impact on performance

### 2. JSON Schema Design

**Schema Version Management**:
- Include schema version in every message
- Allow for future schema evolution
- Document schema changes clearly

**Message Structure Design**:

**Full Update Message**:
```json
{
    "type": "full_update",
    "schema_version": "1.0",
    "timestamp": 1234567890.123,
    "game_frame": 9000,
    "game_time": 300.0,
    "is_paused": false,
    "teams": [...],
    "units": [...],
    "sequence": 1
}
```

**Delta Update Message** (Optional Enhancement):
```json
{
    "type": "delta_update",
    "schema_version": "1.0",
    "sequence": 2,
    "game_frame": 9030,
    "changes": {
        "units_updated": [...],
        "units_destroyed": [...]
    }
}
```

**Control Messages**:
```json
{
    "type": "control",
    "action": "connection_established",
    "widget_version": "1.0.0",
    "capabilities": ["full_update", "compression"]
}
```

### 3. Message Framing Protocol

**Why Framing is Necessary**:
- TCP is stream-based, not message-based
- Receiver needs to know message boundaries
- Multiple messages may arrive in single read
- Single message may be split across reads

**Framing Options to Consider**:

**Option 1: Length-Prefixed** (Recommended):
- Prefix each message with fixed-size length header
- Format: 4-byte length + JSON message
- Easy to parse, efficient, standard approach

**Option 2: Newline-Delimited**:
- Separate messages with newline character
- Simple but requires escaping newlines in JSON
- Common for JSON streaming protocols

**Option 3: Special Delimiter**:
- Use unique byte sequence as separator
- Must ensure delimiter never appears in data

**Implementation Approach**:
- Choose consistent framing method
- Document clearly for receiver implementation
- Handle partial message transmission
- Validate frame integrity

### 4. Serialization Pipeline

**Pipeline Stages**:

1. **Data Preparation**:
   - Convert game state to JSON-friendly format
   - Handle special values (NaN, infinity)
   - Apply configured filters
   - Reduce precision where appropriate

2. **JSON Encoding**:
   - Call dkjson.encode with prepared data
   - Handle encoding errors gracefully
   - Monitor encoding time
   - Track output size

3. **Message Framing**:
   - Add frame header/delimiter
   - Calculate message size
   - Prepare final byte sequence

4. **Queue Management**:
   - Add to transmission queue
   - Check queue size limits
   - Handle overflow scenarios

### 5. Transmission Queue

**Queue Design Requirements**:
- FIFO message ordering
- Configurable size limits
- Overflow handling strategies
- Priority levels (optional)
- Performance metrics

**Queue Implementation**:
- Use Lua table as circular buffer or linked list
- Track head and tail positions
- Implement size limit checking
- Provide queue status methods

**Overflow Strategies**:
1. **Drop Oldest**: Remove oldest messages when full
2. **Drop Newest**: Reject new messages when full
3. **Blocking**: Wait for space (dangerous in game)
4. **Compression**: Reduce message size
5. **Sampling**: Skip updates to reduce rate

**Recommended Strategy**:
- Use drop-oldest for game updates
- Preserve control messages
- Log overflow occurrences
- Notify user of data loss

### 6. Transmission Scheduler

**Scheduling Responsibilities**:
- Coordinate with socket availability
- Respect transmission rate limits
- Handle partial sends
- Retry failed transmissions
- Monitor bandwidth usage

**Transmission Logic**:
```
Per Update Cycle:
1. Check socket state (must be connected)
2. Check if data is ready for transmission
3. Check transmission rate limits
4. Get next message from queue
5. Attempt socket send
6. Handle partial sends
7. Update queue and metrics
8. Repeat until queue empty or limit reached
```

**Partial Send Handling**:
- TCP send may accept only part of message
- Track bytes sent per message
- Resume from correct position
- Maintain message integrity

### 7. Performance Optimization

**Serialization Optimization**:

**String Building**:
- Minimize string concatenations
- Use table.concat for efficiency
- Pre-allocate string buffers if possible
- Reuse temporary tables

**Data Reduction**:
- Reduce coordinate precision (2-3 decimals)
- Omit default/unchanged values
- Use shorter field names (with schema)
- Implement delta updates for large datasets

**Caching Strategies**:
- Cache static data serialization
- Reuse message templates
- Pre-compute common values
- Avoid repeated encoding

**Memory Management**:
- Clear temporary tables
- Reuse message buffers
- Limit queue memory usage
- Force garbage collection if needed

### 8. Bandwidth Management

**Bandwidth Considerations**:
- Calculate bytes per second
- Monitor message sizes
- Implement rate limiting
- Adaptive quality settings

**Adaptive Strategies**:
- Reduce update frequency under load
- Decrease data granularity
- Prioritize important updates
- Implement backpressure handling

**Configuration Options**:
- Maximum bytes per second
- Maximum messages per second
- Minimum time between sends
- Adaptive throttling thresholds

### 9. Error Handling

**Serialization Errors**:
- Invalid data types for JSON
- Circular references
- Encoding failures
- Memory limitations

**Transmission Errors**:
- Socket not ready
- Buffer full
- Connection lost
- Partial send failures

**Recovery Strategies**:
- Skip problematic data
- Clear and rebuild queue
- Reconnection handling
- Graceful degradation

### 10. Message Compression (Optional)

**Compression Considerations**:
- JSON compresses well with gzip
- Lua compression libraries available
- Trade CPU time for bandwidth
- May not be worth overhead for small messages

**Implementation If Needed**:
- Research Lua compression libraries
- Implement compression threshold
- Add compression flag to protocol
- Monitor compression ratio

---

## Integration with Previous Phases

### Phase 1 Integration
- Check connection state before transmission
- Use socket send operations properly
- Coordinate with reconnection logic
- Share error handling patterns

### Phase 2 Integration
- Efficient handoff of collected data
- Avoid unnecessary data copying
- Coordinate update frequencies
- Combined performance budget

### Synchronization Points
- Data collection → Serialization trigger
- Queue status → Collection throttling
- Socket state → Transmission scheduling
- Error states → Unified handling

---

## Testing Guidance

### Test Scenarios

1. **Basic Transmission**:
   - Send single message
   - Verify JSON validity
   - Check message framing
   - Confirm reception

2. **High Volume Testing**:
   - Rapid message generation
   - Queue limit testing
   - Overflow handling
   - Performance monitoring

3. **Large Message Testing**:
   - Maximum unit count scenarios
   - Message size limits
   - Partial send handling
   - Fragmentation behavior

4. **Network Conditions**:
   - Slow receiver (backpressure)
   - Intermittent connectivity
   - High latency simulation
   - Bandwidth limitations

5. **Error Recovery**:
   - Encoding failures
   - Queue overflow
   - Socket errors
   - Memory pressure

### Validation Tools
- External JSON validator
- Protocol analyzer (Wireshark)
- Custom test receiver
- Performance profiler
- Memory usage monitor

### Test Receiver Implementation
Create test receiver that:
- Accepts TCP connections
- Parses message frames
- Validates JSON structure
- Simulates slow consumption
- Logs statistics

---

## Protocol Documentation

### Message Frame Format
Document clearly for receiver implementations:
- Frame structure (header + body)
- Byte order (endianness)
- Size limits
- Error indicators

### JSON Schema
Provide comprehensive schema documentation:
- All message types
- Field descriptions
- Value ranges
- Optional vs required fields
- Version differences

### Example Messages
Include real examples:
- Minimal message
- Typical message
- Maximum complexity
- Error messages
- Control messages

---

## Common Pitfalls to Avoid

1. **Message Boundary Errors**: Incorrect framing corrupts stream
2. **Queue Memory Leaks**: Unbounded growth crashes game
3. **Blocking Operations**: Socket send blocking game loop
4. **JSON Escape Errors**: Special characters breaking parsing
5. **Precision Loss**: Floating point accuracy issues
6. **String Concatenation**: Performance killer in Lua
7. **Partial Send Ignorance**: Lost data from incomplete sends
8. **Bandwidth Explosion**: Uncontrolled transmission rate

---

## Success Criteria for Phase 3

Your implementation is complete when:

1. JSON serialization works reliably for all data types
2. Message framing protocol is correctly implemented
3. Transmission queue manages overflow gracefully
4. Partial sends are handled properly
5. Performance stays within budget (<2ms total)
6. Memory usage remains stable
7. Error recovery works without data corruption
8. Bandwidth usage is predictable and controllable
9. External tools can parse messages reliably
10. Integration with Phases 1-2 is seamless

---

## Preparation for Phase 4

Consider these aspects for Phase 4 integration:
- User feedback on transmission status
- Queue size visualization
- Bandwidth usage display
- Error notification methods
- Configuration UI elements

---

## Performance Guidelines

### Target Metrics
- Serialization time: <0.5ms for typical update
- Queue operations: <0.1ms per message
- Transmission time: <0.3ms per send attempt
- Memory overhead: <500KB for queue
- Bandwidth usage: <100KB/s typical

### Optimization Priority
1. Minimize serialization time
2. Efficient queue operations
3. Reduce message size
4. Batch transmissions
5. Cache where possible

---

## Additional Notes

- Start with simple, complete messages before optimizing
- Test with real network conditions early
- Consider message versioning from the beginning
- Document protocol thoroughly for receiver developers
- JSON validity is critical - malformed JSON breaks everything
- Frame protocol must be rock-solid
- Queue overflow is better than game freeze
- Monitor actual bandwidth usage in production
- Consider compatibility with common JSON streaming tools
- Think about debugging and diagnostic needs

Remember: Phase 3 is the bridge between game data and external tools. The serialization format and transmission protocol you implement here define the entire API. Focus on reliability, efficiency, and clear documentation. A well-implemented Phase 3 makes external tool development straightforward and robust.
