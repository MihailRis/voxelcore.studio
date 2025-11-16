local project_control = require "project_control"

function on_open()
    local projects_dir = "export:projects"

    local projects = {}
    local dirs = file.list(projects_dir)
    for i, path in ipairs(dirs) do
        local project = toml.parse(file.read(file.join(path, "project.toml")))
        project.path = path
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
