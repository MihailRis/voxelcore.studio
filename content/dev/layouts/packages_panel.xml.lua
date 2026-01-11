local util = require "util"
local ui_util = require "ui_util"
local project_control = require "project_control"
local validation = require "validation"

local refresh

function remove_from_project(packid)
    project_control.remove_pack(packid)
    refresh()
end

local function create_packs_list(packs_panel, packs, callback, context_menu, data)
    for packid, info in pairs(packs) do
        info = table.copy(info)
        info.id_verbose = packid
        info.icon = info.id .. ".icon"
        info.description = info.description or gui.str("No description")
        if callback then
            info.callback = string.format("%s(%s)", callback, string.escape(packid))
        end
        if context_menu then
            info.right_callback = string.format("%s(%s)", context_menu, string.escape(packid))
        end
        local iconfile = file.join(info.path, "icon.png")
        if file.exists(iconfile) then
            util.load_texture(iconfile, info.icon)
        else
            info.icon = "gui/no_icon"
        end
        packs_panel:add(gui.template("pack", info), data)
    end
end

refresh = function()
    local packs_panel = document.packsList
    local packs = project_control.get_packs()

    packs_panel:clear()
    create_packs_list(packs_panel, packs, nil, "show_context_menu")
end

function refresh_search(text)
    for packid, info in pairs(project_control.get_available()) do
        if not string.find(packid, text) and not string.find(info.title, text) then
            gui.root["pack_"..packid].zIndex = 1e8
            gui.root["pack_"..packid].visible = false
        else
            gui.root["pack_"..packid].zIndex = 0
            gui.root["pack_"..packid].visible = true
        end
    end
end

function add_content()
    local id = "dialog_"..random.uuid()

    local callback = function(packid)
        gui.root[id]:destruct()
        project_control.add_pack(packid)
        refresh()
    end

    gui.root.root:add(string.format([[
        <container id='%s' color='#00000080' size-func='-1,-1' z-index='10'>
            <panel color='#507090E0' size='500' padding='16'
                   gravity='center-center' interval='4'>
                <container size='400'>
                    <panel id='%s.packs' size-func='-1,-1'></panel>
                </container>
                <textbox id='%s.filter' padding='2' 
                    sub-consumer='function(x) DATA.refresh_search(x) end'/>
                <button onclick='gui.root["%s"]:destruct()'>@Cancel</button>
            </panel>
        </container>
    ]], id, id, id, id), {callback=callback, refresh_search=refresh_search})

    local packs_panel = gui.root[id..".packs"]
    local packs = project_control.get_available()

    gui.root[id..".filter"].focused = true
    create_packs_list(packs_panel, packs, "(function(x) DATA.callback(x) end)", nil, {callback=callback})
end

function new_pack()
    gui.show_input_dialog("Enter new pack id", function(packid)
        project_control.create_pack(packid)
    end, function(text)
        return validation.check_pack_id(text) and not project_control.pack_exists(text)
    end, gui.str("Create"))
end

function show_context_menu(packid)
    local pos = input.get_mouse_pos()
    ui_util.show_context_menu(pos, {
        {"Remove from project", string.format("DATA.remove_from_project(%s)", string.escape(packid))},
    }, {
        ui_util = ui_util,
        remove_from_project = remove_from_project,
    })
end

local initialized = false
function on_open()
    if not initialized then
        events.on("dev:add_pack", function(packid)
            refresh()
        end)
        initialized = true
    end
    refresh()
end
