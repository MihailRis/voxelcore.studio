local util = require "util"

local this = {}
local project_packs = {}

function this.load_project(path)
    local project_file = file.join(path, "project.toml")
    local project_info = toml.parse(file.read(project_file))

    project_packs = util.load_packs_info(file.join(path, "content"))
end

function this.get_packs()
    return project_packs
end

return this
