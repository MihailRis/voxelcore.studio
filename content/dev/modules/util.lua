local this = {}

local format_parsers = {
    toml=toml.parse,
    json=json.parse,
    yaml=yaml.parse,
}

function this.read_object(filename)
    local ext = file.ext(filename)
    return format_parsers[ext](file.read(filename))
end

function this.read_pack_info(package_file)
    local dir = file.parent(package_file)
    local info = this.read_object(package_file)
    info.id = info.id or file.stem(dir)
    info.path = dir
    return info
end

function this.load_packs_info(content_dir)
    if not file.isdir(content_dir) then
        return {}
    end
    local packs_info = {}
    local dirs = file.list(content_dir)
    for i, pack_dir in ipairs(dirs) do
        local package_file = file.join(pack_dir, "package.json")
        if not file.isfile(package_file) then
            goto continue
        end
        local success, pack_info = pcall(this.read_pack_info, package_file)
        if not success then
            debug.error("could not read pack info: "..pack_info)
            goto continue
        end
        packs_info[pack_info.id] = pack_info
        ::continue::
    end
    return packs_info
end

function this.get_project_path(name)
    return file.join("user:projects", name)
end

return this
