local ui_util = require "ui_util"
local client = require "debugging_client"

events.on("dev:debugging_paused", function()
    document.continue_btn.visible = true
end)

events.on("dev:debugging_stopped", function()
    document.continue_btn.visible = false
    document.run_btn.src = "gui/play"
    document.connect_btn.enabled = true
end)

events.on("dev:debugging_resumed", function()
    document.continue_btn.visible = false
end)

events.on("dev:debugging_started", function()
    document.run_btn.src = "gui/stop"
    document.connect_btn.enabled = false
end)

function show_file_context_menu()
    local elem = document.file_btn
    local pos = vec2.add(elem.pos, {0, elem.size[2]})
    ui_util.show_context_menu(pos, {
        {"Open project", "gui.root.main_frame.src = 'dev:projects'"},
        {"Exit", "DATA.ui_util.quit_app(true)"}
    }, {ui_util = ui_util})
end

function start_debugging()
    if client.is_debugging() then
        client.terminate()
    else
        client.start_debugging(function() end, function() end)
    end
end

function connect_debugging()
    if not client.is_debugging() then
        client.connect_debugging(function()
            document.run_btn.src = "gui/stop"
            document.connect_btn.enabled = false
        end, function()
            document.run_btn.src = "gui/play"
            document.connect_btn.enabled = true
        end, 6043)
    end
end

function resume_debugging()
    if client.is_debugging() then
        client.resume()
    end
end

function update()
    client.update(0.01)
end

function on_open()
   document.root:setInterval(10, update)

    input.add_callback("dev.run_debug", function()
        if not client.is_debugging() then
            client.start_debugging(function() end, function() end)
        elseif client.is_paused() then
            client.resume()
        end
    end, document.root, true)
end
