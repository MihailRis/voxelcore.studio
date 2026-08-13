local debugging_client = require "debugging_client"
local project_control = require "project_control"
local registry = require "common/registry"
local tabs = {}
local prev_tab

local function add_side_tab(doc, icon, tooltip)
    document.sideToolbar:add(string.format([[
        <image src='%s' interactive='true' color='#FFFFFF80'
            hover-color='#FFFFFFFF' tooltip='%s'
            onclick='document.left_panel.src = "%s"'/>
    ]], icon, tooltip, doc))
end

events.on("dev:debugging_resumed", function()
    local tb_list = document.traceback
    tb_list:clear()

    local locals_panel = document.locals
    locals_panel:clear()
end)

events.on("dev:log_append", function(s)
    document.output.caret = -1
    document.output:paste(s..'\n')
end)

local function find_tab(docid)
    for i, tab in ipairs(tabs) do
        if tab.tab_id == docid then
            return tab
        end
    end
end

local function index_of_tab(docid)
    for i, tab in ipairs(tabs) do
        if tab.tab_id == docid then
            return i
        end
    end
end

local function switch_to_tab(docid)
    if prev_tab and prev_tab.exists then
        prev_tab.color = {0, 0, 0, 40}
        prev_tab.hoverColor = {0, 0, 0, 120}
        prev_tab = nil
    end
    local target = find_tab(docid)
    if not target then
        return
    end
    document.editorPanel.src = docid
    target = document[target.id]
    target.color = {0, 0, 0, 120}
    target.hoverColor = {0, 0, 0, 240}
    prev_tab = target
end

local function close_tab(docid)
    local target = find_tab(docid)
    if not target then
        return
    end
    local index = index_of_tab(docid)
    document[target.id]:destruct()
    table.remove_value(tabs, target)
    if prev_tab.id == target.id then
        if #tabs == 0 then
            document.editorPanel.src = ""
        elseif index - 1 == #tabs then
            switch_to_tab(tabs[index - 1].tab_id)
        else
            switch_to_tab(tabs[index].tab_id)
        end
    end
end

local function add_tab(title, docid)
    local tabid =  "tab-" .. docid
    document.tabsPanel:add(gui.template("editor_tab", {
        id = tabid,
        title = string.escape_xml(title),
        tab_id = docid,
    }), {
        switch_to_tab = switch_to_tab,
        close_tab = close_tab,
    })
    table.insert(tabs, {
        id = tabid,
        tab_id = docid,
    })
    return docid
end

events.on("dev:request_open_file", function(tag, filename, path, target_line)
    local editor = registry.get_editor(tag)
    local instanceid = editor.."."..random.uuid()
    gui.load_document(editor, instanceid)
    document.editorPanel.src = instanceid
    events.emit("dev:open_file", filename, path, target_line)
    add_tab(file.name(filename), instanceid)
    switch_to_tab(instanceid)
end)

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
    show_locals(stack, 1)

    local tb_list = document.traceback
    local srcsize = tb_list.size
    for _, frame in ipairs(stack) do
        local internal_path = project_control.get_internal_path(frame.source) or "?"
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

function on_open()
    add_side_tab("dev:packages_panel", "gui/package", gui.str("Package"))
    add_side_tab("dev:files_panel", "gui/code", gui.str("Scripts"))
    document.left_panel.src = "dev:packages_panel"
end
