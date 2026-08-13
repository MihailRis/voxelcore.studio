local this = {}

local editors = {}
local default_editor = "dev:layouts/editors/code_editor.xml"

function this.register_editor(file_type, doc_name)
    editors[file_type] = doc_name
end

function this.get_editor(file_type)
    return editors[file_type] or default_editor
end

return this
