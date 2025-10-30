--------------------------------------------------------------------------------
-- BAR Live Data Export Widget - Phase 1: Socket Infrastructure
-- Exports real-time game data via TCP socket to external tools
-- Author: AI Implementation
-- Version: 1.0.1 (FIXED: LuaSocket loading)
-- License: GNU GPL v2 or later
--
-- FIX SUMMARY: 
-- The original code declared 'local socket = nil' which shadowed the engine's
-- global socket library. This version uses 'tcpSocket' for the connection and
-- explicitly accesses the library via rawget(_G, "socket").
--------------------------------------------------------------------------------

function widget:GetInfo()
    return {
        name = "Live Data Export",
        desc = "Exports real-time game data via TCP socket to external applications",
        author = "AI Implementation",
        date = "2025-01-29",
        license = "GNU GPL v2 or later",
        layer = -10,  -- Low layer to avoid conflicts
        enabled = true,  -- Enabled by default for testing
    }
end

--------------------------------------------------------------------------------
-- Configuration Defaults
--------------------------------------------------------------------------------

local DEFAULT_CONFIG = {
    host = "127.0.0.1",
    port = 9876,
    autoReconnect = true,
    maxRetryDelay = 30,  -- seconds
    initialRetryDelay = 1,  -- seconds
    logLevel = "INFO",  -- INFO, WARNING, ERROR
}

--------------------------------------------------------------------------------
-- Connection States
--------------------------------------------------------------------------------

local STATE_DISCONNECTED = "DISCONNECTED"
local STATE_CONNECTING = "CONNECTING"
local STATE_CONNECTED = "CONNECTED"
local STATE_RECONNECTING = "RECONNECTING"
local STATE_ERROR = "ERROR"

--------------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------------

local tcpSocket = nil  -- FIXED: Renamed from 'socket' to avoid shadowing the library
local connectionState = STATE_DISCONNECTED
local config = {}
local lastConnectionAttempt = 0
local currentRetryDelay = DEFAULT_CONFIG.initialRetryDelay
local retryCount = 0
local lastError = nil
local widgetStartTime = 0

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

local function Log(level, message)
    if config.logLevel == "ERROR" and level ~= "ERROR" then return end
    if config.logLevel == "WARNING" and level == "INFO" then return end

    local prefix = "[LiveDataExport] "
    if level == "WARNING" then
        prefix = "[LiveDataExport WARNING] "
    elseif level == "ERROR" then
        prefix = "[LiveDataExport ERROR] "
    end

    Spring.Echo(prefix .. message)
end

local function GetTime()
    return Spring.GetGameSeconds() or os.clock()
end

local function SetConnectionState(newState)
    if connectionState ~= newState then
        Log("INFO", "State change: " .. connectionState .. " -> " .. newState)
        connectionState = newState
        if newState == STATE_CONNECTED then
            currentRetryDelay = DEFAULT_CONFIG.initialRetryDelay
            retryCount = 0
        end
    end
end

--------------------------------------------------------------------------------
-- Socket Management Functions
--------------------------------------------------------------------------------

local function CreateSocket()
    if tcpSocket then
        tcpSocket:close()
        tcpSocket = nil
    end

    -- FIXED: Properly access the LuaSocket library
    -- In Spring 98.0+, the socket library is pre-loaded by the engine
    -- We use rawget to access the 'socket' library from the global environment
    -- (not our 'tcpSocket' variable)
    local socketLib = rawget(getfenv(0), "socket")
    if not socketLib then
        Log("ERROR", "LuaSocket library not available - ensure LuaSocketEnabled is not set to 0")
        SetConnectionState(STATE_ERROR)
        return false
    end

    -- Create TCP socket from the library
    tcpSocket = socketLib.tcp()
    if not tcpSocket then
        Log("ERROR", "Failed to create TCP socket")
        SetConnectionState(STATE_ERROR)
        return false
    end

    -- Set non-blocking mode immediately
    tcpSocket:settimeout(0)
    Log("INFO", "Socket created and set to non-blocking mode")
    return true
end

local function AttemptConnection()
    if not tcpSocket then
        if not CreateSocket() then return false end
    end

    local result, err = tcpSocket:connect(config.host, config.port)

    if result then
        -- Connection established immediately (rare for non-blocking)
        Log("INFO", "Connected to " .. config.host .. ":" .. config.port)
        SetConnectionState(STATE_CONNECTED)
        return true
    elseif err == "timeout" then
        -- Connection in progress (expected for non-blocking)
        SetConnectionState(STATE_CONNECTING)
        return true
    else
        -- Actual connection error
        lastError = err
        Log("WARNING", "Connection failed: " .. err)
        SetConnectionState(STATE_ERROR)
        return false
    end
end

local function CheckConnectionStatus()
    if not tcpSocket then return false end

    -- Use select to check if socket is writable (connected)
    -- FIXED: Access socketLib directly for the select method
    local socketLib = rawget(getfenv(0), "socket")
    if not socketLib then
        Log("WARNING", "Socket library unavailable during connection check")
        return false
    end

    local ready = socketLib.select({tcpSocket}, nil, 0)
    if ready and #ready > 0 then
        Log("INFO", "Connection established to " .. config.host .. ":" .. config.port)
        SetConnectionState(STATE_CONNECTED)
        return true
    end

    return false
end

local function CloseSocket()
    if tcpSocket then
        tcpSocket:close()
        tcpSocket = nil
        Log("INFO", "Socket closed")
    end
    SetConnectionState(STATE_DISCONNECTED)
end

--------------------------------------------------------------------------------
-- Reconnection Logic
--------------------------------------------------------------------------------

local function ShouldAttemptReconnect()
    if not config.autoReconnect then return false end
    if connectionState == STATE_CONNECTED then return false end

    local currentTime = GetTime()
    return (currentTime - lastConnectionAttempt) >= currentRetryDelay
end

local function HandleReconnection()
    lastConnectionAttempt = GetTime()

    if AttemptConnection() then
        retryCount = retryCount + 1
        Log("INFO", "Reconnection attempt " .. retryCount .. " (delay: " .. currentRetryDelay .. "s)")
    else
        -- Increase retry delay exponentially
        currentRetryDelay = math.min(currentRetryDelay * 2, config.maxRetryDelay)
        Log("WARNING", "Reconnection failed, next attempt in " .. currentRetryDelay .. " seconds")
        SetConnectionState(STATE_RECONNECTING)
    end
end

--------------------------------------------------------------------------------
-- Widget Lifecycle Functions
--------------------------------------------------------------------------------

function widget:Initialize()
    widgetStartTime = GetTime()
    Log("INFO", "Live Data Export widget initializing")

    -- Load configuration
    local savedConfig = self:GetConfigData()
    if savedConfig then
        for k, v in pairs(DEFAULT_CONFIG) do
            config[k] = savedConfig[k] or v
        end
    else
        config = table.copy(DEFAULT_CONFIG)
    end

    Log("INFO", "Configuration loaded - Host: " .. config.host .. ", Port: " .. config.port)

    -- Initial connection attempt
    if config.autoReconnect then
        AttemptConnection()
    end
end

function widget:Shutdown()
    Log("INFO", "Live Data Export widget shutting down")
    CloseSocket()
end

function widget:Update(dt)
    -- Main update loop - keep execution under 2ms total

    if connectionState == STATE_DISCONNECTED and config.autoReconnect then
        if ShouldAttemptReconnect() then
            HandleReconnection()
        end
    elseif connectionState == STATE_CONNECTING then
        if CheckConnectionStatus() then
            -- Connection successful
        end
    elseif connectionState == STATE_CONNECTED then
        -- Check if connection is still alive (basic keep-alive)
        -- For now, just ensure socket exists
        if not tcpSocket then
            Log("WARNING", "Socket lost unexpectedly")
            SetConnectionState(STATE_ERROR)
        end
    elseif connectionState == STATE_ERROR or connectionState == STATE_RECONNECTING then
        if ShouldAttemptReconnect() then
            HandleReconnection()
        end
    end
end

function widget:GetConfigData()
    return config
end

function widget:SetConfigData(data)
    if data then
        config = data
        Log("INFO", "Configuration updated")
    end
end

--------------------------------------------------------------------------------
-- Console Commands (for debugging)
--------------------------------------------------------------------------------

function widget:TextCommand(command)
    local cmd = command:lower():gsub("^%s*(.-)%s*$", "%1")

    if cmd == "livedata status" then
        Log("INFO", "Status: " .. connectionState ..
             ", Host: " .. config.host ..
             ", Port: " .. config.port ..
             ", Retries: " .. retryCount)
        if lastError then
            Log("INFO", "Last error: " .. lastError)
        end
    elseif cmd:find("^livedata connect") then
        Log("INFO", "Manual connection attempt")
        AttemptConnection()
    elseif cmd:find("^livedata disconnect") then
        Log("INFO", "Manual disconnection")
        CloseSocket()
    elseif cmd:find("^livedata sethost%s+(.+)") then
        local host = cmd:match("^livedata sethost%s+(.+)")
        config.host = host
        Log("INFO", "Host set to: " .. host)
    elseif cmd:find("^livedata setport%s+(%d+)") then
        local port = tonumber(cmd:match("^livedata setport%s+(%d+)"))
        if port and port > 0 and port < 65536 then
            config.port = port
            Log("INFO", "Port set to: " .. port)
        else
            Log("ERROR", "Invalid port number")
        end
    else
        return false  -- Command not handled
    end

    return true
end

--------------------------------------------------------------------------------
-- End of Widget
--------------------------------------------------------------------------------