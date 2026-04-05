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

function this.get_project_path(name)
    return file.join("user:projects", name)
end

function this.load_texture(filename, alias)
    return assets.load_texture(file.read_bytes(filename), alias )
end

return this
