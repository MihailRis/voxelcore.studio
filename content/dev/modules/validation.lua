local min_pack_length = 3
local max_pack_length = 20

local this = {}

function this.check_pack_id(text)
    local len = #text
    if len < min_pack_length or len > max_pack_length then
        return false
    end
    return text:match("^[%a_%-][%w_%-]+$")
end

return this;
