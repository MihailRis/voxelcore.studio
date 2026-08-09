local project_control = require "project_control"
local validation = require "validation"

function open_file(filename, path, target_line)
    events.emit("dev:open_file", filename, path, target_line)
end

local registry = {}

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
            icon = file_info.tag,
            open_func = "open_file",
            filename = file_info.filename,
            content_path = file_info.content_path,
            path = file.path(parent) == "" and parent or parent .. "/",
            name = file.name(filename)
        }))
    end
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
        if file.ext(script_file) ~= "lua" then
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
    if file_type == "module" then
        gui.show_input_dialog("Enter script name", function(name)
            local packinfo = project_control.get_packs()["base"]
            local packpath = packinfo.path
            local info = {
                tag = "module",
                filename = file.join(file.join(packpath, "modules"), name..".lua"),
                content_path = packinfo.id..":modules/"..name..".lua"
            }
            local snippet = file.read("dev:presets/snippets/module_template.lua")
            local snippet_line = snippet:find(":here")
            if snippet_line then
                snippet_line = select(2, string.gsub(snippet:sub(1, snippet_line), "\n", "")) + 1
            end
            print("snippet_line", snippet_line)
            file.write(info.filename, snippet)
            table.insert(registry, info)
            build_files_list(registry)
            open_file(info.filename, info.content_path, snippet_line)
        end, validation.check_content_unit_id)
    end
end

function on_open()
    registry = {}
    local packs = project_control.get_packs()
    for i, packinfo in pairs(packs) do
        local modules_dir = file.join(packinfo.path, "modules")
        local scripts_dir = file.join(packinfo.path, "scripts")
        if file.isdir(modules_dir) then
            add_files(packinfo.id..":modules", file.list(modules_dir), "module")
        end
        if file.isdir(scripts_dir) then
            add_files(packinfo.id..":scripts", file.list(scripts_dir), "lua_script")
        end
        build_files_list(registry)
    end
end
