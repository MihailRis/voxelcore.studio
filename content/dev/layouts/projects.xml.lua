local util = require "util"
local project_control = require "project_control"

function on_open()
    local projects_dir = "user:projects"

    local projects = {}
    local dirs = file.list(projects_dir)
    for i, path in ipairs(dirs) do
        local project = toml.parse(file.read(file.join(path, "project.toml")))
        project.path = path
        project.id = random.uuid()
        document.projects:add(gui.template("project", project))
        table.insert(projects, project)
    end
end

function open_project(path)
    local status, err = pcall(project_control.load_project, path)
    if not status then
        debug.error(string.format("could not open project '%s': %s", path, err))
        return
    end
    gui.root.main_frame.src = 'dev:main'
end

function new_project()
    gui.show_input_dialog(gui.str("Project name"), function(name)
        local status, err = pcall(project_control.new_project, name)
        if not status then
            debug.error(string.format("could not create project %s: %s",
                string.escape(name), err))
            return
        else
            open_project(util.get_project_path(name))
        end
    end, function(text)
        if text:find("/") or text:find("\\") then
            return
        end
        return #text > 0 and not file.exists(util.get_project_path(text))
    end, gui.str("Create project"))
end
