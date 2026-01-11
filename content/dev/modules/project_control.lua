local util = require "util"

local this = {}
local project_packs = {}
local available_packs
local dirty_packs = true
local current_project

function this.new_project(name)
    local path = util.get_project_path(name)
    local project_content = {
        name=name,
        title=name,
    }
    local project_file = file.join(path, "project.toml")
    file.mkdirs(path)
    file.write(project_file, toml.tostring(project_content))
end

function this.load_project(path)
    debug.log("opening project "..string.escape(path))
    local project_file = file.join(path, "project.toml")
    local project_info = toml.parse(file.read(project_file))
    project_info.path = path

    project_packs = util.load_packs_info(file.join(path, "content"))
    current_project = project_info
end

function this.get_packs()
    return project_packs
end

function this.get_available()
    if available_packs and not dirty_packs then
        return available_packs
    end
    dirty_packs = true

    local packs = {}
    local content_path = file.join(current_project.path, "content")
    table.merge(packs, util.load_packs_info("user:content"))
    table.merge(packs, util.load_packs_info(content_path))
    available_packs = packs
    return packs
end

function this.pack_exists(packid)
    return project_packs[packid] ~= nil or this.get_available()[packid] ~= nil
end

function this.get_current_project()
    return current_project
end

function this.add_pack(packid)
    local info = this.get_available()[packid]
    if info == nil then
        error("invalid state: newly created pack info not found")
    end
    project_packs[packid] = info
    events.emit("dev:add_pack", packid)
end

function this.remove_pack(packid)
    project_packs[packid] = nil
end

function this.create_pack(packid)
    local title = packid:gsub("_", " ")
    title = title:sub(1, 1):upper() .. title:sub(2)
    local info = {
        id = packid,
        title = title,
    }
    local packdir = file.join(current_project.path, "content/"..packid)
    file.mkdirs(packdir)
    file.write(file.join(packdir, "package.json"), json.tostring(info, true))
    dirty_packs = true
    this.add_pack(packid)
end

return this
