local Schedule = require "core:schedule"

local this = {}

local socket
local debugging
local connected
local disconnected_callback
local schedule = Schedule()
local app
local listener

local function send(msg)
    if not socket then
        return
    end
    socket:send(byteutil.pack("<I", #msg))
    socket:send(msg)
end

function this.init(app_lib)
    app = app_lib
end

local breakpoints = {}
local value_callback

local function get_file_breakpoints(source)
    local file_breakpoints = breakpoints[source]
    if not file_breakpoints then
        file_breakpoints = {}
        breakpoints[source] = file_breakpoints
    end
    return file_breakpoints
end

function this.toggle_breakpoint(source, line)
    local file_breakpoints = get_file_breakpoints(source)

    if file_breakpoints[line] then
        this.remove_breakpoint(source, line)
        return false
    else
        this.set_breakpoint(source, line)
        return true
    end
end

function this.set_breakpoint(source, line)
    local file_breakpoints = breakpoints[source]
    if file_breakpoints[line] ~= nil then
        return
    end
    if socket then
        send(string.format([[{"type": "set-breakpoint", "source": "%s", "line": %s}]], source, line))
    end
    file_breakpoints[line] = true
end

function this.remove_breakpoint(source, line)
    local file_breakpoints = breakpoints[source]
    if file_breakpoints[line] == nil then
        return
    end
    if socket then
        send(string.format([[{"type": "remove-breakpoint", "source": "%s", "line": %s}]], source, line))
    end
    file_breakpoints[line] = nil
end

function this.get_file_breakpoints(source)
    local points = get_file_breakpoints(source)
    local list = {}
    for line, _ in pairs(points) do
        table.insert(list, line)
    end
    return list
end

function this.terminate()
    if not connected then
        return
    end
    send([[{"type": "terminate"}]])
    events.emit("dev:debugging_stopped")
    connected = false
end

function this.resume()
    if not connected then
        return
    end
    send([[{"type": "resume"}]])
    events.emit("dev:debugging_resumed")
end

function this.is_debugging()
    return debugging
end

function this.request_value(frame_index, var_index, callback)
    if not connected then
        return
    end
    send(string.format([[{
        "type": "get-value",
        "frame": %s,
        "local": %s,
        "path": []
    }]], frame_index, var_index))
    value_callback = callback
end

function this.cancel_value_request()
    value_callback = nil
end

local function listen_server(socket)
    coroutine.yield()
    socket:recv_async(8) -- skipping header

    while socket:is_connected() do
        local msg_size_bytes = socket:recv_async(4)
        if not msg_size_bytes then
            break
        end
        local msg_size = byteutil.unpack("<I", msg_size_bytes)
        local payload = socket:recv_async(msg_size)
        if not payload then
            break
        end
        local data = json.parse(utf8.tostring(payload))
        -- debug.print(data)
        if data.type == "paused" then
            events.emit("dev:debugging_paused", data.reason, data.stack)
        elseif data.type == "value" then
            if value_callback then
                value_callback(data.value)
                value_callback = nil
            end
        end
    end
end

function this.connect_debugging(on_connected, on_disconnected, port)
    disconnected_callback = on_disconnected
    debugging = true

    network.tcp_connect("localhost", port, function(sock)
        socket = sock
        debug.log("connected to debugging server "..sock:get_address())
        connected = true
        sock:send({0x76, 0x63, 0x2D, 0x64, 0x62, 0x67, 0x00, 0x01})
        send([[{
            "type": "connect",
            "disconnect-action": "terminate"
        }]])
        for source, file_breakpoints in pairs(breakpoints) do
            for line, _ in pairs(file_breakpoints) do
                send(string.format([[{"type": "set-breakpoint",
                    "source": "%s", "line": %s}]], source, line))
            end
        end
        if on_connected then
            on_connected()
        end
        events.emit("dev:debugging_started")
        listener = coroutine.create(listen_server)
        coroutine.resume(listener, socket)
    end, function(sock, message)
        debug.error(string.format("could not connect to debugging server: %s", message))
        on_disconnected(message)
        debugging = false
        events.emit("dev:debugging_stopped")
    end)
end

function this.start_debugging(on_connected, on_disconnected)
    if not app then
        error("debugging_client.init(app) was not called")
    end
    local port = app.start_debug_instance()
    schedule:set_timeout(500, function()
        this.connect_debugging(on_connected, on_disconnected, port)
    end)
end

function this.update(delta)
    schedule:tick(delta)
    if socket and not socket:is_connected() then
        debugging = false
        socket = nil
        if disconnected_callback then
            disconnected_callback()
            disconnected_callback = nil
        end
    end
    if listener then
        if coroutine.status(listener) == "dead" then
            listener = nil
            this.terminate()
            return
        end
        local success, err = coroutine.resume(listener)
        if not success then
            listener = nil
            debug.error(string.format(
                "debugging server listener uncaught error: %s", err))
            this.terminate()
        end
    end
end

return this
