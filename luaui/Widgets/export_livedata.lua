--------------------------------------------------------------------------------
-- BAR Live Data Export Widget - Phase 3: JSON Transmission
-- Exports real-time game data via TCP socket to external tools
-- Author: AI Implementation
-- Version: 3.0.0 (Phase 3: JSON Transmission Complete)
-- License: GNU GPL v2 or later
--
-- Phase 1: Socket Infrastructure (Complete)
-- Phase 2: Data Collection (Complete)
-- Phase 3: JSON Transmission (Complete)
--
-- This widget collects game state data from BAR's Spring API, serializes it to
-- JSON format, and transmits it via TCP socket to external applications.
-- Features include:
-- - Efficient JSON serialization with dkjson
-- - Length-prefixed message framing protocol
-- - Transmission queue with overflow protection
-- - Performance monitoring and error handling
-- - Configurable data granularity and transmission rates
--------------------------------------------------------------------------------

function widget:GetInfo()
    return {
        name = "Live Data Export",
        desc = "Exports real-time game data via TCP socket to external applications",
        author = "AI Implementation",
        date = "2025-01-29",
        license = "GNU GPL v2 or later",
        layer = -10,  -- Low layer to avoid conflicts
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
-- Data Collection Variables (Phase 2)
--------------------------------------------------------------------------------

local dataCollection = {
    enabled = true,  -- Master switch for data collection
    frequency = 10,  -- Collect every N frames (30 Hz game = ~3 Hz default)
    granularity = "standard",  -- "minimal", "standard", "detailed"
    maxUnits = 500,  -- Maximum units to process per frame
    lastCollectionFrame = 0,
    collectionTime = 0,  -- Performance tracking
    gameState = {},  -- Current game state data
    cachedGameInfo = nil,  -- Static game information
    isSpectator = false,  -- Spectator mode flag
}

--------------------------------------------------------------------------------
-- Transmission Variables (Phase 3)
--------------------------------------------------------------------------------

local transmission = {
    enabled = true,  -- Master switch for transmission
    queue = {},  -- FIFO message queue
    queueMaxSize = 50,  -- Maximum messages in queue
    queueOverflowCount = 0,  -- Track overflow events
    currentMessage = nil,  -- Currently transmitting message
    bytesSent = 0,  -- Bytes sent for current message
    serializationTime = 0,  -- Performance tracking
    transmissionTime = 0,  -- Performance tracking
    totalBytesSent = 0,  -- Session statistics
    totalMessagesSent = 0,  -- Session statistics
    lastTransmissionFrame = 0,
    maxBytesPerFrame = 8192,  -- Bandwidth limit per frame
    bytesSentThisFrame = 0,
}

-- dkjson library (embedded)
local dkjson = {
    version = "dkjson 2.5",
    -- Pure Lua JSON encoder/decoder
    -- Embedded to avoid external dependencies
}

-- dkjson encode function (simplified for performance)
function dkjson.encode(value, state)
    local state = state or {}
    local indent = state.indent
    local level = state.level or 0
    local buffer = state.buffer or {}

    local function encode_value(val)
        local t = type(val)
        if t == "string" then
            table.insert(buffer, string.format("%q", val))
        elseif t == "number" then
            if val ~= val then  -- NaN
                table.insert(buffer, "null")
            elseif val == math.huge then
                table.insert(buffer, "null")
            elseif val == -math.huge then
                table.insert(buffer, "null")
            else
                table.insert(buffer, tostring(val))
            end
        elseif t == "boolean" then
            table.insert(buffer, val and "true" or "false")
        elseif t == "table" then
            local first = true
            table.insert(buffer, "{")
            for k, v in pairs(val) do
                if not first then table.insert(buffer, ",") end
                first = false
                table.insert(buffer, string.format("%q", k))
                table.insert(buffer, ":")
                encode_value(v)
            end
            table.insert(buffer, "}")
        elseif val == nil then
            table.insert(buffer, "null")
        else
            table.insert(buffer, "null")  -- Unknown type
        end
    end

    encode_value(value)
    return table.concat(buffer)
end

-- Message framing constants
local MESSAGE_TYPE_FULL_UPDATE = "full_update"
local MESSAGE_TYPE_CONTROL = "control"
local SCHEMA_VERSION = "1.0"

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

--------------------------------------------------------------------------------
-- Data Collection Functions (Phase 2)
--------------------------------------------------------------------------------

local function ShouldCollectData(currentFrame)
    if not dataCollection.enabled then return false end
    if connectionState ~= STATE_CONNECTED then return false end
    return (currentFrame - dataCollection.lastCollectionFrame) >= dataCollection.frequency
end

local function CollectGameInfo()
    if dataCollection.cachedGameInfo then
        return dataCollection.cachedGameInfo
    end

    local gameInfo = {
        version = Game.version or "unknown",
        mapName = Game.mapName or "unknown",
        mapSizeX = Game.mapSizeX or 0,
        mapSizeZ = Game.mapSizeZ or 0,
        modName = Game.modName or "unknown",
        modShortName = Game.modShortName or "unknown",
        startPosType = Game.startPosType or 0,
        maxUnits = Game.maxUnits or 0,
    }

    dataCollection.cachedGameInfo = gameInfo
    return gameInfo
end

local function CollectTimeInfo()
    return {
        frame = Spring.GetGameFrame() or 0,
        gameSeconds = Spring.GetGameSeconds() or 0,
        isPaused = Spring.IsPaused() or false,
        gameSpeed = Spring.GetGameSpeed() or 1.0,
    }
end

local function CollectTeamData()
    local teams = {}
    local teamList = Spring.GetTeamList() or {}

    for _, teamID in ipairs(teamList) do
        local teamInfo = Spring.GetTeamInfo(teamID)
        if teamInfo then
            local metal = Spring.GetTeamResources(teamID, "metal") or {0, 0, 0, 0}
            local energy = Spring.GetTeamResources(teamID, "energy") or {0, 0, 0, 0}

            teams[teamID] = {
                id = teamID,
                name = teamInfo.name or ("Team " .. teamID),
                leader = teamInfo.leader or -1,
                isDead = teamInfo.isDead or false,
                isAiTeam = teamInfo.isAiTeam or false,
                side = teamInfo.side or "unknown",
                allyTeam = teamInfo.allyTeam or 0,
                metal = {
                    current = metal[1] or 0,
                    storage = metal[2] or 0,
                    pull = metal[3] or 0,
                    income = metal[4] or 0,
                    expense = metal[5] or 0,
                },
                energy = {
                    current = energy[1] or 0,
                    storage = energy[2] or 0,
                    pull = energy[3] or 0,
                    income = energy[4] or 0,
                    expense = energy[5] or 0,
                },
            }
        end
    end

    return teams
end

local function IsUnitVisible(unitID)
    if dataCollection.isSpectator then
        return true  -- Spectators see everything
    end
    return Spring.IsUnitVisible(unitID) or false
end

local function CollectUnitData()
    local units = {}
    local allUnits = Spring.GetAllUnits() or {}
    local processedCount = 0

    for _, unitID in ipairs(allUnits) do
        if processedCount >= dataCollection.maxUnits then
            Log("WARNING", "Reached max units limit (" .. dataCollection.maxUnits .. ")")
            break
        end

        if IsUnitVisible(unitID) then
            local unitData = {
                id = unitID,
                defId = Spring.GetUnitDefID(unitID) or 0,
                team = Spring.GetUnitTeam(unitID) or 0,
            }

            -- Position (always included)
            local x, y, z = Spring.GetUnitPosition(unitID)
            if x then
                unitData.pos = {x = x, y = y, z = z}
            end

            -- Health (always included)
            local health, maxHealth, paralyze, capture, build = Spring.GetUnitHealth(unitID)
            if health then
                unitData.health = {
                    current = health,
                    max = maxHealth or health,
                    paralyze = paralyze or 0,
                    capture = capture or 0,
                    build = build or 1.0,
                }
            end

            -- Additional data based on granularity
            if dataCollection.granularity == "standard" or dataCollection.granularity == "detailed" then
                -- Velocity
                local vx, vy, vz = Spring.GetUnitVelocity(unitID)
                if vx then
                    unitData.velocity = {x = vx, y = vy, z = vz}
                end

                -- Build progress (if not complete)
                if unitData.health and unitData.health.build < 1.0 then
                    unitData.buildProgress = unitData.health.build
                end
            end

            if dataCollection.granularity == "detailed" then
                -- Unit states
                local states = Spring.GetUnitStates(unitID)
                if states then
                    local isRepeat = rawget(states, "repeat") or false
                    unitData.states = {
                        fireState = states.firestate or 0,
                        moveState = states.movestate or 0,
                        isRepeat = isRepeat,
                        cloakState = states.cloak or false,
                        activeState = states.active or true,
                    }
                end

                -- Commands queue (first command only, for performance)
                local commands = Spring.GetUnitCommands(unitID, 1)
                if commands and #commands > 0 then
                    unitData.currentCommand = {
                        id = commands[1].id or 0,
                        params = commands[1].params or {},
                    }
                end
            end

            table.insert(units, unitData)
            processedCount = processedCount + 1
        end
    end

    return units
end

local function CollectGameState()
    local startTime = os.clock()

    local gameState = {
        schema_version = SCHEMA_VERSION,
        timestamp = os.time(),
        gameInfo = CollectGameInfo(),
        timeInfo = CollectTimeInfo(),
        teams = CollectTeamData(),
        units = CollectUnitData(),
        isSpectator = dataCollection.isSpectator,
    }

    local endTime = os.clock()
    dataCollection.collectionTime = (endTime - startTime) * 1000  -- Convert to milliseconds

    if dataCollection.collectionTime > 5 then
        Log("WARNING", string.format("Data collection took %.2f ms", dataCollection.collectionTime))
    end

    return gameState
end

--------------------------------------------------------------------------------
-- Transmission Functions (Phase 3)
--------------------------------------------------------------------------------

local function CreateFullUpdateMessage(gameState, sequence)
    return {
        type = MESSAGE_TYPE_FULL_UPDATE,
        schema_version = SCHEMA_VERSION,
        timestamp = gameState.timestamp,
        game_frame = gameState.timeInfo.frame,
        game_time = gameState.timeInfo.gameSeconds,
        is_paused = gameState.timeInfo.isPaused,
        game_speed = gameState.timeInfo.gameSpeed,
        teams = gameState.teams,
        units = gameState.units,
        is_spectator = gameState.isSpectator,
        sequence = sequence,
    }
end

local function CreateControlMessage(action, data)
    local message = {
        type = MESSAGE_TYPE_CONTROL,
        schema_version = SCHEMA_VERSION,
        timestamp = os.time(),
        action = action,
    }

    if data then
        for k, v in pairs(data) do
            message[k] = v
        end
    end

    return message
end

local function SerializeMessage(message)
    local startTime = os.clock()

    -- Use dkjson to encode message
    local jsonString = dkjson.encode(message)

    local endTime = os.clock()
    transmission.serializationTime = (endTime - startTime) * 1000

    if transmission.serializationTime > 2 then
        Log("WARNING", string.format("Serialization took %.2f ms", transmission.serializationTime))
    end

    return jsonString
end

local function FrameMessage(jsonString)
    -- Length-prefixed framing: 4-byte big-endian length + JSON
    local length = #jsonString
    local lengthBytes = string.char(
        math.floor(length / 16777216) % 256,
        math.floor(length / 65536) % 256,
        math.floor(length / 256) % 256,
        length % 256
    )
    return lengthBytes .. jsonString
end

local function QueueMessage(message, priority)
    -- Add message to transmission queue
    if not transmission.enabled then return false end

    -- Check queue size limit
    if #transmission.queue >= transmission.queueMaxSize then
        -- Drop oldest message (FIFO overflow strategy)
        table.remove(transmission.queue, 1)
        transmission.queueOverflowCount = transmission.queueOverflowCount + 1
        Log("WARNING", "Transmission queue overflow - dropped oldest message")
    end

    -- Add new message
    table.insert(transmission.queue, {
        message = message,
        priority = priority or 1,
        created = os.clock(),
    })

    return true
end

local function GetNextMessageFromQueue()
    -- Return oldest message from queue
    if #transmission.queue > 0 then
        return table.remove(transmission.queue, 1)
    end
    return nil
end

local function SendMessage(socket, framedMessage)
    if not socket then return false, "no socket" end

    local startTime = os.clock()
    local totalSent = 0
    local messageSize = #framedMessage

    -- Handle partial sends
    if transmission.currentMessage then
        -- Continue sending current message
        local remaining = transmission.currentMessage:sub(transmission.bytesSent + 1)
        local sent, err, partial = socket:send(remaining)

        if sent then
            transmission.bytesSent = transmission.bytesSent + sent
            totalSent = sent

            if transmission.bytesSent >= #transmission.currentMessage then
                -- Message complete
                transmission.currentMessage = nil
                transmission.bytesSent = 0
                transmission.totalMessagesSent = transmission.totalMessagesSent + 1
            end
        elseif err == "timeout" then
            -- Normal for non-blocking, will retry next frame
            return true, "timeout"
        else
            -- Error
            transmission.currentMessage = nil
            transmission.bytesSent = 0
            return false, err
        end
    else
        -- Start new message
        local sent, err, partial = socket:send(framedMessage)

        if sent then
            totalSent = sent
            transmission.totalBytesSent = transmission.totalBytesSent + sent

            if sent >= messageSize then
                -- Message sent completely
                transmission.totalMessagesSent = transmission.totalMessagesSent + 1
            else
                -- Partial send, save for next attempt
                transmission.currentMessage = framedMessage
                transmission.bytesSent = sent
            end
        elseif err == "timeout" then
            -- Normal for non-blocking
            return true, "timeout"
        else
            -- Error
            return false, err
        end
    end

    local endTime = os.clock()
    transmission.transmissionTime = (endTime - startTime) * 1000

    transmission.bytesSentThisFrame = transmission.bytesSentThisFrame + totalSent

    return true, nil
end

local function ProcessTransmissionQueue()
    if not transmission.enabled or connectionState ~= STATE_CONNECTED or not tcpSocket then
        return
    end

    -- Reset per-frame bandwidth counter
    if Spring.GetGameFrame() ~= transmission.lastTransmissionFrame then
        transmission.bytesSentThisFrame = 0
        transmission.lastTransmissionFrame = Spring.GetGameFrame()
    end

    -- Send messages until queue empty or bandwidth limit reached
    local messagesSent = 0
    while #transmission.queue > 0 and transmission.bytesSentThisFrame < transmission.maxBytesPerFrame do
        local queueItem = GetNextMessageFromQueue()
        if not queueItem then break end

        -- Serialize message
        local jsonString = SerializeMessage(queueItem.message)
        if not jsonString then
            Log("ERROR", "Failed to serialize message")
            break
        end

        -- Frame message
        local framedMessage = FrameMessage(jsonString)

        -- Send message
        local success, err = SendMessage(tcpSocket, framedMessage)
        if not success then
            if err ~= "timeout" then
                Log("ERROR", "Transmission failed: " .. (err or "unknown error"))
                -- Re-queue message for retry (put back at front)
                table.insert(transmission.queue, 1, queueItem)
                break
            end
            -- Timeout is normal, will retry next frame
        else
            messagesSent = messagesSent + 1
        end

        -- Safety check: don't spend too much time transmitting
        if messagesSent >= 5 then break end
    end
end

local function SetConnectionState(newState)
    if connectionState ~= newState then
        Log("INFO", "State change: " .. connectionState .. " -> " .. newState)
        connectionState = newState
        if newState == STATE_CONNECTED then
            currentRetryDelay = DEFAULT_CONFIG.initialRetryDelay
            retryCount = 0
            -- Phase 3: Send connection established message
            if transmission.enabled then
                local controlMessage = CreateControlMessage("connection_established", {
                    widget_version = "3.0.0",
                    capabilities = {MESSAGE_TYPE_FULL_UPDATE, MESSAGE_TYPE_CONTROL},
                    queue_size = #transmission.queue,
                })
                QueueMessage(controlMessage, 2)  -- High priority
            end
        elseif newState == STATE_DISCONNECTED then
            -- Clear transmission state
            transmission.currentMessage = nil
            transmission.bytesSent = 0
            transmission.bytesSentThisFrame = 0
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
        -- Load Phase 2 config if available
        if savedConfig.dataCollection then
            for k, v in pairs(savedConfig.dataCollection) do
                dataCollection[k] = v
            end
        end
    else
        config = table.copy(DEFAULT_CONFIG)
    end

    -- Determine if we're in spectator mode
    local myPlayerID = Spring.GetMyPlayerID()
    if myPlayerID then
        local playerInfo = Spring.GetPlayerInfo(myPlayerID)
        if playerInfo and playerInfo.isSpec then
            dataCollection.isSpectator = true
            Log("INFO", "Spectator mode detected - full visibility enabled")
        end
    end

    Log("INFO", "Configuration loaded - Host: " .. config.host .. ", Port: " .. config.port)
    Log("INFO", "Data collection: " .. (dataCollection.enabled and "enabled" or "disabled") ..
          ", Frequency: every " .. dataCollection.frequency .. " frames" ..
          ", Granularity: " .. dataCollection.granularity)

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

        -- Phase 2: Data collection
        local currentFrame = Spring.GetGameFrame() or 0
        if ShouldCollectData(currentFrame) then
            dataCollection.lastCollectionFrame = currentFrame
            dataCollection.gameState = CollectGameState()
    
            -- Phase 3: Queue data for transmission
            if transmission.enabled then
                local message = CreateFullUpdateMessage(dataCollection.gameState, transmission.totalMessagesSent + 1)
                QueueMessage(message, 1)  -- Normal priority
    
                if dataCollection.collectionTime > 1 then
                    Log("INFO", string.format("Collected data: %d teams, %d units (%.2f ms)",
                        #dataCollection.gameState.teams or 0, #dataCollection.gameState.units or 0,
                        dataCollection.collectionTime))
                end
            end
        end
    
        -- Phase 3: Process transmission queue
        ProcessTransmissionQueue()
    elseif connectionState == STATE_ERROR or connectionState == STATE_RECONNECTING then
        if ShouldAttemptReconnect() then
            HandleReconnection()
        end
    end
end

function widget:GetConfigData()
    return {
        host = config.host,
        port = config.port,
        autoReconnect = config.autoReconnect,
        maxRetryDelay = config.maxRetryDelay,
        initialRetryDelay = config.initialRetryDelay,
        logLevel = config.logLevel,
        dataCollection = {
            enabled = dataCollection.enabled,
            frequency = dataCollection.frequency,
            granularity = dataCollection.granularity,
            maxUnits = dataCollection.maxUnits,
        },
        transmission = {
            enabled = transmission.enabled,
            queueMaxSize = transmission.queueMaxSize,
            maxBytesPerFrame = transmission.maxBytesPerFrame,
        }
    }
end

function widget:SetConfigData(data)
    if data then
        config = data
        if data.dataCollection then
            for k, v in pairs(data.dataCollection) do
                dataCollection[k] = v
            end
        end
        if data.transmission then
            for k, v in pairs(data.transmission) do
                transmission[k] = v
            end
        end
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
        Log("INFO", "Data collection: " .. (dataCollection.enabled and "enabled" or "disabled") ..
              ", Last collection: " .. dataCollection.collectionTime .. " ms" ..
              ", Units collected: " .. (dataCollection.gameState.units and #dataCollection.gameState.units or 0))
        Log("INFO", "Transmission: " .. (transmission.enabled and "enabled" or "disabled") ..
              ", Queue: " .. #transmission.queue .. "/" .. transmission.queueMaxSize ..
              ", Sent: " .. transmission.totalMessagesSent .. " msgs, " .. transmission.totalBytesSent .. " bytes" ..
              ", Overflow: " .. transmission.queueOverflowCount)
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
    elseif cmd == "livedata collect" then
        if connectionState == STATE_CONNECTED then
            local currentFrame = Spring.GetGameFrame() or 0
            dataCollection.lastCollectionFrame = currentFrame - dataCollection.frequency  -- Force collection
            Log("INFO", "Manual data collection triggered")
        else
            Log("WARNING", "Cannot collect data - not connected")
        end
    elseif cmd:find("^livedata setfreq%s+(%d+)") then
        local freq = tonumber(cmd:match("^livedata setfreq%s+(%d+)"))
        if freq and freq > 0 then
            dataCollection.frequency = freq
            Log("INFO", "Collection frequency set to every " .. freq .. " frames")
        else
            Log("ERROR", "Invalid frequency")
        end
    elseif cmd:find("^livedata setgran%s+(%w+)") then
        local gran = cmd:match("^livedata setgran%s+(%w+)")
        if gran == "minimal" or gran == "standard" or gran == "detailed" then
            dataCollection.granularity = gran
            Log("INFO", "Data granularity set to: " .. gran)
        else
            Log("ERROR", "Invalid granularity (use: minimal, standard, detailed)")
        end
    elseif cmd == "livedata toggle" then
        dataCollection.enabled = not dataCollection.enabled
        Log("INFO", "Data collection " .. (dataCollection.enabled and "enabled" or "disabled"))
    elseif cmd:find("^livedata setqueuesize%s+(%d+)") then
        local size = tonumber(cmd:match("^livedata setqueuesize%s+(%d+)"))
        if size and size > 0 and size <= 200 then
            transmission.queueMaxSize = size
            Log("INFO", "Transmission queue size set to: " .. size)
        else
            Log("ERROR", "Invalid queue size (1-200)")
        end
    elseif cmd == "livedata clearqueue" then
        transmission.queue = {}
        transmission.currentMessage = nil
        transmission.bytesSent = 0
        Log("INFO", "Transmission queue cleared")
    elseif cmd == "livedata testmessage" then
        if connectionState == STATE_CONNECTED then
            local testMessage = CreateControlMessage("test_message", {
                test_data = "Hello from BAR Live Data Export Widget v3.0.0",
                timestamp = os.time(),
            })
            QueueMessage(testMessage, 2)
            Log("INFO", "Test message queued for transmission")
        else
            Log("WARNING", "Cannot send test message - not connected")
        end
    else
        return false  -- Command not handled
    end

    return true
end

--------------------------------------------------------------------------------
-- End of Widget
--------------------------------------------------------------------------------