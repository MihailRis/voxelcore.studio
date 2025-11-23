local project_control = require "project_control"

function open_file(filename, path, name)
    events.emit("dev:open_file", filename, path, name)
end

function on_open()
    local packs = project_control.get_packs()
    for i, packinfo in pairs(packs) do
        local modules_dir = file.join(packinfo.path, "modules")
        if not file.isdir(modules_dir) then
            goto continue
        end
        local modules_list = file.list(modules_dir)
        for j, script_file in ipairs(modules_list) do
            if file.ext(script_file) ~= "lua" then
                goto continue
            end
            local path = packinfo.id..":modules"
            local name = file.name(script_file)
            document.filesList:add(gui.template("script_file", {
                icon="module",
                open_func="open_file",
                filename=script_file,
                content_path=file.join(path, name),
                path=file.path(path) == "" and path or path .. "/",
                name=name
            }))
            ::continue::
        end
        ::continue::
    end
end
