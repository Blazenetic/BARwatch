# Phase 2 Implementation Guide: Data Collection
## BAR Live Data Export Widget - AI Code Bot Instructions

---

## Overview

You are implementing Phase 2 of the BAR Live Data Export Widget. With Phase 1's socket infrastructure complete and tested, Phase 2 focuses on collecting game state data from the Spring/Recoil engine. This phase establishes the data collection pipeline that will feed into the transmission system in Phase 3.

### Phase 2 Goal
Create an efficient, configurable system that collects relevant game state data from BAR's Spring API, respects visibility rules (fog of war), and prepares structured data for later serialization.

---

## Prerequisites

### Required from Phase 1
- Working socket connection management
- Non-blocking update loop
- State machine for connection status
- Performance monitoring framework
- Error handling patterns

### New Requirements for Phase 2
- Deep understanding of Spring's Lua API
- Knowledge of BAR's game mechanics
- Data structure design skills
- Performance optimization techniques
- Memory management awareness

---

## Context and Constraints

### Spring Engine API Access
- **Widget Context**: Unsynced (local player's perspective only)
- **Visibility Rules**: Must respect fog of war in multiplayer
- **API Categories**: Available APIs include Unit, Team, Game, and more
- **Performance Cost**: Each API call has overhead - batch when possible
- **Data Freshness**: Game state updates at 30 Hz (every ~33ms)

### Data Collection Principles
1. **Respect Visibility**: Only collect data the local player can see
2. **Minimize API Calls**: Cache values that don't change frequently
3. **Structured Organization**: Design clear data hierarchies
4. **Configurable Granularity**: Allow users to choose detail level
5. **Performance First**: Always prioritize game performance

---

## Implementation Components

### 1. Data Collection Scheduler

**Purpose**: Control when and how often data is collected from the game state.

**Design Considerations**:
- Not every frame needs data collection (30 Hz game, but maybe 10 Hz export)
- Different data types may need different update frequencies
- Allow dynamic adjustment based on performance

**Scheduling Strategy**:
- Implement configurable collection frequency (e.g., every N frames)
- Consider frame-based timing vs. real-time intervals
- Separate schedules for different data categories:
  - High frequency: Unit positions, health (every update)
  - Medium frequency: Resources, team data (every second)
  - Low frequency: Static game info (once at start)

**Implementation Approach**:
- Track frames since last collection
- Use modulo operation for regular intervals
- Provide override for immediate collection
- Allow frequency adjustment via configuration

### 2. Game State Categories

**Core Data Categories to Implement**:

#### Game Information (Static/Rare Updates)
- Game version and mod information
- Map name and dimensions
- Total number of teams/players
- Game settings and options
- Victory conditions

#### Time Information (Every Update)
- Current game frame number
- Game time in seconds
- Game speed/pause state
- Real time vs game time ratio

#### Team/Player Data (Medium Frequency)
- Team IDs and alliances
- Player names and status
- Team colors and faction
- Alive/dead status
- Spectator information

#### Economic Data (High Frequency)
- Current metal and energy amounts
- Income and expenditure rates
- Storage capacity
- Resource sharing information
- Constructor allocation

#### Unit Data (Configurable Frequency)
- Unit positions and velocities
- Health and shield values
- Build progress for incomplete units
- Current orders/commands
- Unit definition information

#### Combat Statistics (Event-Driven)
- Damage dealt/received
- Units killed/lost
- Key engagement locations
- Weapon states

### 3. Spring API Integration

**Key API Functions to Utilize**:

**Game State APIs**:
- `Spring.GetGameFrame()` - Current simulation frame
- `Spring.GetGameSeconds()` - Game time in seconds
- `Spring.IsPaused()` - Pause state
- `Spring.GetGameSpeed()` - Current game speed

**Team/Player APIs**:
- `Spring.GetTeamList()` - All team IDs
- `Spring.GetTeamInfo()` - Team details
- `Spring.GetTeamResources()` - Economic data
- `Spring.GetPlayerInfo()` - Player details
- `Spring.GetMyTeamID()` - Local player's team

**Unit APIs**:
- `Spring.GetAllUnits()` - All visible unit IDs
- `Spring.GetTeamUnits()` - Units for specific team
- `Spring.GetUnitPosition()` - 3D position
- `Spring.GetUnitHealth()` - Current/max health
- `Spring.GetUnitDefID()` - Unit type identifier
- `Spring.GetUnitVelocity()` - Movement data
- `Spring.GetUnitStates()` - Unit states/settings

**Visibility APIs**:
- `Spring.IsUnitVisible()` - Check visibility
- `Spring.IsPosInLos()` - Position in line of sight
- `Spring.GetUnitLosState()` - Detailed LOS info
- `Spring.IsUnitInView()` - In camera view

### 4. Data Structure Design

**Design Principles**:
- Hierarchical organization for clarity
- Consistent field naming conventions
- Optional fields for configurable detail
- Flat structures where appropriate for performance
- Pre-allocate tables when size is known

**Suggested Data Structure**:

```
gameState = {
    -- Frame/timing data
    frame = number,
    gameTime = number,
    isPaused = boolean,
    
    -- Game metadata (cached)
    gameInfo = {
        version = string,
        mapName = string,
        modName = string,
        -- etc.
    },
    
    -- Team array
    teams = {
        [teamID] = {
            metal = {current, income, expense, storage},
            energy = {current, income, expense, storage},
            unitCount = number,
            -- etc.
        }
    },
    
    -- Unit array (only visible units)
    units = {
        [1] = {
            id = number,
            defId = number,
            team = number,
            pos = {x, y, z},
            health = {current, max},
            -- optional based on detail level
            velocity = {x, y, z},
            buildProgress = number,
            -- etc.
        }
    }
}
```

### 5. Visibility and Fog of War

**Critical Implementation**:
- Always check unit visibility before including in data
- Respect spectator vs player perspective
- Handle full visibility in spectator mode
- Consider partial visibility states

**Visibility Checking Pattern**:
1. Determine local player's perspective (player vs spectator)
2. For each unit, check visibility status
3. Include only appropriate data based on visibility
4. Handle radar vs visual contact differently if needed

**Spectator Mode Handling**:
- Detect spectator state early
- Enable full data collection if spectating
- Clearly indicate spectator mode in data

### 6. Performance Optimization

**Optimization Strategies**:

**API Call Reduction**:
- Batch unit queries when possible
- Cache static information
- Use team-specific queries wisely
- Avoid redundant visibility checks

**Memory Management**:
- Reuse table structures between updates
- Clear old data properly
- Pre-allocate arrays when size is known
- Avoid creating temporary tables in hot paths

**Conditional Collection**:
- Skip detailed data for distant units
- Reduce frequency for static units
- Priority system for important units
- Configurable detail levels

**Performance Monitoring**:
- Track collection time per category
- Measure memory allocation
- Identify bottlenecks
- Adaptive throttling if needed

### 7. Configuration System

**User-Configurable Options**:

**Collection Frequency**:
- Updates per second (1-30)
- Different rates for different data types
- Automatic vs manual mode

**Data Granularity Levels**:
- Minimal: Just positions and health
- Standard: Include resources and basic states
- Detailed: All available information
- Custom: Selective categories

**Filtering Options**:
- Unit type filters
- Team filters
- Spatial filters (area of interest)
- Importance thresholds

**Performance Settings**:
- Maximum units to process
- Collection time budget
- Auto-throttle threshold
- Debug/profiling mode

### 8. Data Validation

**Validation Requirements**:
- Verify API calls don't return nil
- Ensure unit IDs are valid
- Check array bounds
- Validate numeric ranges
- Handle missing or invalid data gracefully

**Error Recovery**:
- Skip invalid units
- Use defaults for missing data
- Log anomalies without disrupting collection
- Maintain data consistency

### 9. Event-Driven Collection

**Optional Enhancement**:
Consider implementing event-driven collection for certain data:
- Unit creation/destruction events
- Resource threshold events
- Combat events
- Game state changes

**Widget Callins to Consider**:
- `widget:UnitCreated()`
- `widget:UnitDestroyed()`
- `widget:UnitDamaged()`
- `widget:TeamDied()`
- `widget:GameStart()`
- `widget:GameOver()`

---

## Integration with Phase 1

### Connection State Awareness
- Only collect data when connected or about to connect
- Suspend collection during disconnection
- Buffer small amount of data during reconnection
- Clear buffers appropriately

### Performance Coordination
- Share performance budget between phases
- Coordinate update frequencies
- Combined error handling
- Unified configuration system

---

## Testing Guidance

### Test Scenarios

1. **Basic Collection**:
   - Start single-player game
   - Verify all data categories collected
   - Check data structure validity
   - Monitor performance impact

2. **Visibility Testing**:
   - Test in multiplayer as player
   - Verify fog of war respected
   - Test spectator mode
   - Validate partial visibility handling

3. **Performance Testing**:
   - Large unit count scenarios (500+ units)
   - Measure collection time
   - Check memory usage
   - Verify frame rate stability

4. **Configuration Testing**:
   - Test all granularity levels
   - Verify frequency adjustments
   - Test filtering options
   - Validate configuration persistence

5. **Edge Cases**:
   - Empty game state
   - Single unit scenarios
   - Maximum unit counts
   - Rapid game state changes

### Data Validation Tests
- Print collected data to console
- Verify structure consistency
- Check value ranges
- Compare with known game state

---

## Common Pitfalls to Avoid

1. **Visibility Violations**: Never expose enemy information in fog of war
2. **API Spam**: Don't call same API multiple times per frame
3. **Memory Leaks**: Clear references to destroyed units
4. **Nil Checks**: Always verify API returns before using
5. **Performance Spikes**: Avoid collecting everything every frame
6. **Table Pollution**: Don't leave stale data in structures
7. **Update Cascades**: Prevent one update triggering others

---

## Success Criteria for Phase 2

Your implementation is complete when:

1. All major game state categories are collected
2. Data structures are well-organized and consistent
3. Fog of war is properly respected
4. Performance impact stays under 2ms total (with Phase 1)
5. Configurable collection frequencies work correctly
6. Data granularity levels function as expected
7. Memory usage remains stable over time
8. Error handling prevents data corruption
9. Integration with Phase 1 is seamless
10. Comprehensive testing validates accuracy

---

## Preparation for Phase 3

Consider these aspects for smooth Phase 3 integration:
- Data structure design that's JSON-friendly
- Efficient data change detection
- Minimal data copying requirements
- Clear separation of collection and formatting
- Documented data schema

---

## Performance Guidelines

### Target Metrics
- Collection time: <1ms for standard scenarios
- Memory allocation: <100KB per collection
- Update frequency: 10Hz default, 30Hz maximum
- Unit processing: 500+ units without degradation

### Optimization Priority
1. Minimize API calls (highest impact)
2. Reuse memory structures
3. Batch operations
4. Cache static data
5. Implement detail levels

---

## Additional Notes

- Start with minimal data set, expand gradually
- Test with real game scenarios early
- Document data schema thoroughly
- Consider replay compatibility
- Unit definition data can be cached aggressively
- Team count rarely changes during game
- Focus on what external tools actually need
- Data accuracy is more important than completeness

Remember: Phase 2 is about establishing reliable data collection from the game state. Focus on accuracy, performance, and respecting game rules. The data structure you design here will define the API for all external tools, so think carefully about organization and extensibility.
