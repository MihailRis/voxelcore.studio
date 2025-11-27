local this = {}

local editor
local document
local breakpoint_indicators = {}

function this.init(target_document)
    document = target_document
    editor = document.editor
end

local function add_breakpoint_indicator(line)
    local line_pos = editor:lineY(line) + 2
    editor:add("<container id='breakpoint_"..line.."' color='#00FF0010'"
    .." size-func='-1,24' pos='0,"..line_pos.."'></container>")
    table.insert(breakpoint_indicators, line)
end

local function remove_breakpoint_indicator(line)
    local indicator = document["breakpoint_"..line]
    if indicator.exists then
        indicator:destruct()
    end
end

function this.clear()
    for i, line in ipairs(breakpoint_indicators) do
        remove_breakpoint_indicator(line)
    end
end

function this.setup(breakpoints)
    for i, line in ipairs(breakpoints) do
        add_breakpoint_indicator(line)
    end
end

function this.set_breakpoint(line, state)
    if state then
        add_breakpoint_indicator(line)
    else
        remove_breakpoint_indicator(line)
    end
end

return this
