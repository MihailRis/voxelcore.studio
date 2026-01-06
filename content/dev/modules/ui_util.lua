local this = {
    focus_window = nil
}

function this.init(app)
    this.focus_window = app.focus
end

function this.show_context_menu(pos, options, data)
    local contextid = random.random(10000, 99999)
    local xml = ""
    for i, option in ipairs(options) do
        local text = option[1]
        local action = option[2] or "local _"
        xml = xml.."<button onfocus='"..action
        .."' color='#101010D0' text-align='left' hover-color='#000000D0'>@"
        ..text.."</button>"
    end
    gui.root.root:add("<panel id='context"
        ..contextid.."' color='0' interval='0' pos='"
        ..pos[1]..","..pos[2].."' size='260' ondefocus='gui.root.context"
        ..contextid..":destruct()'>"..xml.."</panel>", data)
    gui.root["context"..contextid].focused = true
end

return this
