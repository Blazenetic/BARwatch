# BAR Live Data Export Widget - LuaSocket Loading Bug Report

## Issue Summary
The BAR Live Data Export Widget fails to load the LuaSocket library in the Beyond All Reason (BAR) game client, despite LuaSocket being confirmed as available in the Recoil Engine.

## Error Details
```
[LiveDataExport ERROR] Failed to load LuaSocket library - tried: require 'socket', global 'socket', require 'luasocket'
```

## Environment
- **Game**: Beyond All Reason (BAR)
- **Engine**: Recoil Engine (Spring RTS fork)
- **Lua Version**: 5.1/5.2 compatible
- **Widget Context**: Unsynced widget
- **Platform**: Windows 10

## What We've Tried
The widget attempts to load LuaSocket using multiple methods:

1. `require("socket")` - Standard Lua require
2. Check for global `socket` variable
3. `require("luasocket")` - Alternative naming

All methods fail, despite documentation stating LuaSocket is built into the Recoil Engine.

## Expected Behavior
- LuaSocket should be available for TCP socket operations
- Widget should successfully create TCP connections
- No blocking operations that freeze the game

## Actual Behavior
- Widget initialization fails immediately
- Cannot proceed to socket creation
- Error prevents any network functionality

## Research Context
According to available documentation:
- LuaSocket is integrated into Spring/Recoil engine
- TCP connections are enabled by default since Spring 98.0
- UDP is restricted but TCP should work
- No additional configuration required for basic TCP client operations

## Code Location
The failing code is in `luaui/Widgets/export_livedata.lua`, lines 94-118, in the `CreateSocket()` function.

## Impact
- Phase 1 (Socket Infrastructure) cannot be completed
- Blocks progression to Phase 2 (Data Collection)
- Core functionality (TCP export) is unavailable

## Requested Investigation
Please research the exact method to access LuaSocket in the BAR/Recoil engine environment. Specific questions:

1. What is the correct require path for LuaSocket in BAR?
2. Is LuaSocket exposed as a global or through a different mechanism?
3. Are there any engine-specific initialization requirements?
4. Is there alternative networking API available in Recoil Engine?

## References
- BAR GitHub: https://github.com/beyond-all-reason/Beyond-All-Reason
- Recoil Engine: https://github.com/beyond-all-reason/RecoilEngine
- Lua API Docs: https://beyond-all-reason.github.io/RecoilEngine/docs/lua-api/
- Spring LuaSocket: https://springrts.com/wiki/Lua_Socket

## Test Case
To reproduce:
1. Place `export_livedata.lua` in `BAR/data/games/BAR.sdd/luaui/Widgets/`
2. Launch BAR in development mode
3. Load the widget (should auto-load or use `/luaui reload`)
4. Check console for the error message

## Current Workaround
None available - socket functionality is essential for the widget's core purpose.