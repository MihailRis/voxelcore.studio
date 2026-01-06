local util = require "util"

local this = {}
local project_packs = {}
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

function this.get_current_project()
    return current_project
end

return this
