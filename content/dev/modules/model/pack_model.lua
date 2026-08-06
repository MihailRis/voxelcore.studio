local pack_mt = {
    __index = {}
}

return function(id, path, title)
    return setmetatable({
        id = id,
        path = path,
        title = title,
    }, pack_mt)
end
