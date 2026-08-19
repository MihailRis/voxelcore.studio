local project_control = require "project_control"
local validation = require "validation"
local ui_util = require "ui_util"

local registry = {}

local function find_in_registry(filename)
    for i, entry in ipairs(registry) do
        if entry.filename == filename then
            return entry
        end
    end
end

local function build_files_list(files, highlighted_part)
    local files_list = document.filesList
    files_list.scroll = 0
    files_list:clear()

    local sorted_files = table.copy(files)
    table.sort(sorted_files, function(a, b)
        return a.content_path < b.content_path
    end)

    for _, file_info in ipairs(sorted_files) do
        local filename = file_info.content_path
        if highlighted_part then
            filename = filename:gsub(highlighted_part, "**"..highlighted_part.."**")
        end
        local parent = file.parent(filename)

        files_list:add(gui.template("script_file", {
            tag = file_info.tag,
            icon = file_info.tag,
            open_func = "open_file",
            open_context_menu = "open_context_menu",
            filename = file_info.filename,
            content_path = file_info.content_path,
            path = file.path(parent) == "" and parent or parent .. "/",
            name = file.name(filename)
        }))
    end
end

function open_file(tag, filename, path, target_line)
    events.emit("dev:request_open_file", tag, filename, path, target_line)
end

function rename_file(filename)
    gui.show_input_dialog("Enter new name for " .. string.escape(file.name(filename)), function(name)
        local target = find_in_registry(filename)
        if not target then
            return
        end
        local content = file.read(filename)
        local parent = file.parent(filename)
        local prev_filename = target.filename
        local new_filename = file.join(parent, name .. ".lua")
        file.write(new_filename, content)
        file.remove(prev_filename)
        target.filename = new_filename
        target.content_path = file.join(file.parent(target.content_path), name..".lua")
        events.emit("dev:rename_file", prev_filename, new_filename)
        build_files_list(registry)
    end, validation.check_content_unit_id)
end

function delete_file(filename)
    local info = find_in_registry(filename)
    if not info then
        return
    end
    gui.ask("Delete file **"..string.escape(info.content_path).."**?", function()
        table.remove_value(registry, info)
        file.remove(filename)
        events.emit("dev:delete_file", filename)
        build_files_list(registry)
    end)
end

function open_context_menu(filename)
    local mousepos = input.get_mouse_pos()
    ui_util.show_context_menu(mousepos, {
        {"Rename", string.format("DATA.rename_file(%s)", string.escape(filename))},
        {"Delete", string.format("DATA.delete_file(%s)", string.escape(filename))},
    }, {
        rename_file = rename_file,
        delete_file = delete_file,
    })
end

function filter_files(text)
    local pattern_safe = text:pattern_safe();
    local filtered = {}
    for _, file_info in ipairs(registry) do
        local filename = file_info.content_path
        if filename:find(pattern_safe) then
            table.insert(filtered, file_info)
        end
    end
    build_files_list(filtered, pattern_safe)
end

local function add_files(path, files_list, tag)
    for j, script_file in ipairs(files_list) do
        if file.ext(script_file) ~= "lua" and file.ext(script_file) ~= "vca" then
            goto continue
        end
        local name = file.name(script_file)
        local info = {
            tag = tag,
            filename = script_file,
            content_path = file.join(path, name),
        }
        table.insert(registry, info)
        ::continue::
    end
end

function new_file(file_type)
    local packinfo = project_control.get_packs()["base"]
    local packpath = packinfo.path
    if file_type == "module" then
        gui.show_input_dialog("Enter module name", function(name)
            local info = {
                tag = "module",
                filename = file.join(file.join(packpath, "modules"), name..".lua"),
                content_path = packinfo.id..":modules/"..name..".lua"
            }
            local snippet = file.read("dev:presets/snippets/module_template.lua")
            local snippet_line = snippet:find("::snippet_line::")
            if snippet_line then
                snippet_line = select(2, string.gsub(snippet:sub(1, snippet_line), "\n", "")) + 1
                snippet = snippet:gsub("::snippet_line::", "")
            end
            file.write(info.filename, snippet)
            table.insert(registry, info)
            build_files_list(registry)
            open_file(info.tag, info.filename, info.content_path, snippet_line)
        end, validation.check_content_unit_id)
    elseif file_type == "script" then
        gui.show_input_dialog("Enter script name", function(name)
            local info = {
                tag = "script",
                filename = file.join(file.join(packpath, "scripts"), name..".lua"),
                content_path = packinfo.id..":scripts/"..name..".lua"
            }
            file.write(info.filename, "")
            table.insert(registry, info)
            build_files_list(registry)
            open_file(info.tag, info.filename, info.content_path)
        end, validation.check_content_unit_id)
    end
end

function on_open()
    registry = {}
    local packs = project_control.get_packs()
    for i, packinfo in pairs(packs) do
        local modules_dir = file.join(packinfo.path, "modules")
        local scripts_dir = file.join(packinfo.path, "scripts")
        local animation_dir = file.join(packinfo.path, "animation")
        if file.isdir(modules_dir) then
            add_files(packinfo.id..":modules", file.list(modules_dir), "module")
        end
        if file.isdir(scripts_dir) then
            add_files(packinfo.id..":scripts", file.list(scripts_dir), "script")
        end
        if file.isdir(animation_dir) then
            add_files(packinfo.id..":animation", file.list(animation_dir), "animation")
        end
        build_files_list(registry)
    end
end
