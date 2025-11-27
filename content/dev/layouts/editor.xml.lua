local ui_util = require "ui_util"
local project_control = require "project_control"
local debugging_client = require "debugging_client"
local Schedule = require "core:schedule"

local schedule = Schedule()
local current_file = {}

local breakpoints_view = require "breakpoints_view"

local function clear_traceback()
    local tb_list = document.traceback
    tb_list:clear()

    local locals_panel = document.locals
    locals_panel:clear()
end

local function cleanup_editor()
    breakpoints_view.clear()
end

events.on("dev:debugging_stopped", function()
    local pause_position = document.pause_position
    pause_position.visible = false
end)

events.on("dev:debugging_resumed", function()
    local pause_position = document.pause_position
    pause_position.visible = false

    clear_traceback()
end)

local function get_internal_path(source, project_packs)
    project_packs = project_packs or project_control.get_packs()
    if not source:find(':') then
        return
    end
    local prefix, path = parse_path(source)
    local pack_info = project_packs[prefix]
    if not pack_info then
        return
    end
    return file.join(pack_info.path, path)
end

local function add_table(panel, value, path, indent, id_prefix, frame_index, var_id)
    local names = {}
    for name, _ in pairs(value) do
        table.insert(names, name)
    end
    table.sort(names)
    for i, name in ipairs(names) do
        local var_info = value[name]
        local id = id_prefix .. "." .. name
        if var_info.type == "table" then
            local newpath = table.copy(path)
            table.insert(newpath, name)
            local newpathstr = json.tostring(newpath):sub(2)
            newpathstr = newpathstr:sub(1, #newpathstr - 1)
            panel:add(string.format([[
                <panel id="%s" orientation="horizontal" color='0' hover-color="#FFFFFF30"
                       onclick='request_value(%s, %s, {%s}, 0)'>
                    <label margin="%s,2,2,2">%s</label>
                    <label margin="2,2,2,2" color="#FFFFFF40">: %s = </label>
                    <label margin="2,2,2,2">%s</label>
                </panel>
            ]], id, frame_index, var_id, newpathstr, indent * 12 + 2, name, var_info.type, var_info.short))
        else
            panel:add(string.format([[
                <panel size="24" orientation="horizontal" color='0'>
                    <label margin="%s,2,2,2">%s</label>
                    <label margin="2,2,2,2" color="#FFFFFF40">: %s = </label>
                    <label margin="2,2,2,2">%s</label>
                </panel>
            ]], indent * 12 + 2, name, var_info.type, var_info.short))
        end
    end
end

function request_value(frame_index, var_id, path, indent)
    debugging_client.request_value(frame_index, var_id, path, function(value)
        local id = "lv_"..frame_index.."_"..var_id
        for i, elem in ipairs(path) do
            id = id .. "." .. elem
        end
        local panel = document[id]
        add_table(panel, value, path, indent + 1, id, frame_index, var_id)
    end)
end

local function show_locals(stack, frame_index)
    debugging_client.cancel_value_request()

    local locals_panel = document.locals
    locals_panel:clear()
    locals_panel:add([[<label margin="0,0,0,5">@Locals</label>]])

    local locals = stack[frame_index].locals
    for i, var_info in ipairs(locals) do
        if var_info.type == "table" then
            locals_panel:add(string.format([[
                <panel id="lv_%s_%s" color="0">
                    <panel size="24" orientation="horizontal" color='0' 
                           hover-color="#FFFFFF30" 
                           onclick="request_value(%s, %s, {}, 0)">
                        <label margin="2">%s</label>
                        <label margin="2" color="#FFFFFF40">: %s = </label>
                        <label margin="2">%s</label>
                    </panel>
                </panel>
            ]], frame_index - 1, var_info.index,
            frame_index - 1, var_info.index,
            var_info.name, var_info.type, var_info.short))
        else
            locals_panel:add(string.format([[
                <panel size="24" orientation="horizontal" color="0">
                    <label margin="2">%s</label>
                    <label margin="2" color="#FFFFFF40">: %s = </label>
                    <label margin="2">%s</label>
                </panel>
            ]], var_info.name, var_info.type, var_info.short))
        end
    end
end

events.on("dev:debugging_paused", function(reason, stack)
    if not reason then
        return
    end
    local frame_index = 1
    local source = stack[frame_index].source
    local line = stack[frame_index].line
    local project_packs = project_control.get_packs()
    local internal_path = get_internal_path(source, project_packs)
    open_file_in_editor(internal_path, source, line)

    local pause_position = document.pause_position
    pause_position.pos = {0, document.editor:lineY(line) + 2}
    pause_position.visible = true
    ui_util.focus_window()

    clear_traceback()

    show_locals(stack, frame_index)

    local tb_list = document.traceback
    local srcsize = tb_list.size
    for _, frame in ipairs(stack) do
        local internal_path = get_internal_path(frame.source, project_packs) or "?"
        local callback = ""
        local framestr = ""
        if frame.what == "C" then
            framestr = "C/C++ "
        else
            framestr = frame.source..":"..tostring(frame.line).." "
            if file.exists(internal_path) then
                callback = string.format(
                    "open_file_in_editor('%s', '%s', %s)",
                    internal_path, frame.source, frame.line
                )
            else
                callback = "document.editor.text = 'Could not open source file'"
            end
        end
        if frame.name then
            framestr = framestr.."("..tostring(frame.name)..")"
        end
        local color = "#FFFFFF"
        tb_list:add(gui.template("stack_frame", {
            location=framestr,
            color=color,
            callback=callback,
            enabled=file.exists(internal_path)
        }))
    end
    tb_list.size = srcsize
end)

--- Open a file in the code editor.
--- @param internal_path string - actual internal file path
--- @param path string - 'pack:local_path' file path
--- @param target_line integer - the line number to focus on (optional).
function open_file_in_editor(internal_path, path, target_line)
    cleanup_editor()

    debug.log("opening file "..string.escape(path)
        .." ("..internal_path..") in editor")

    local ext = file.ext(path)
    if ext == "xml" or ext == "vcm" then
        document.modelviewer.src = file.stem(path)
        document.modelviewer.visible = true
    else
        document.modelviewer.visible = false
    end
    document.codePanel:refresh()

    local editor = document.editor
    local source = file.read(internal_path):gsub('\t', '    ')
    editor.scroll = 0
    editor.text = source
    editor.focused = true
    editor.syntax = file.ext(path)
    document.title.text = gui.str('File') .. ' - ' .. path
    current_file.path = path
    current_file.internal_path = internal_path
    document.lockIcon.visible = internal_path == nil
    editor.editable = internal_path ~= nil
    document.saveIcon.enabled = current_file.modified

    time.post_runnable(function()
        if target_line then
            editor.caret = editor:linePos(target_line - 1)
        end
        breakpoints_view.setup(debugging_client.get_file_breakpoints(path))
    end)
end

function save_current_file()
    if not current_file.internal_path then
        return
    end
    file.write(current_file.internal_path, document.editor.text)
    current_file.modified = false
    document.saveIcon.enabled = false
    document.title.text = gui.str('File')..' - '..current_file.path
    document.editor.edited = false
end

local function refresh_file_title()
    if current_file.internal_path == "" then
        document.title.text = ""
        return
    end
    local edited = document.editor.edited
    current_file.modified = edited
    document.saveIcon.enabled = edited
    document.title.text = gui.str('File')..' - '..current_file.path
        ..(edited and ' *' or '')
end

function toggle_breakpoint(line)
    local state = debugging_client.toggle_breakpoint(current_file.path, line)
    breakpoints_view.set_breakpoint(line, state)
end

function show_editor_context_menu()
    local editor = document.editor
    local mousepos = input.get_mouse_pos()
    local index = editor:indexByPos(mousepos)
    local line = editor:lineAt(index)
    editor.caret = index
    ui_util.show_context_menu({mousepos[1], mousepos[2]}, {
        {"Toggle Breakpoint (line "..line..")", "DATA.toggle_breakpoint("..line..")"}
    }, {toggle_breakpoint=toggle_breakpoint})
end

function on_control_combination(keycode)
    if keycode == input.keycode("s") then
        save_current_file()
    elseif keycode == input.keycode("r") then
        run_current_file()
    end
end


events.on("dev:open_file", function(internal_path, path)
    open_file_in_editor(internal_path, path, 1)
end)

function on_open()
    breakpoints_view.init(document)

    local editor = document.editor
    editor:add("<container id='pause_position' color='#FFFF0030' size-func='-1,24' visible='false'></container>")

    local project_packs = project_control.get_packs()
    open_file_in_editor(
        file.join(project_packs.base.path, "scripts/hud.lua"),
        "base:scripts/hud.lua", 0
    )

    schedule:set_interval(100, function()
        refresh_file_title()
    end)

    document.root:setInterval(10, function()
        schedule:tick(0.01)
    end)
end
