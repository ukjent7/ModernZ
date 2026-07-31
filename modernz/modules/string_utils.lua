-- modernz :: modules/string_utils.lua
-- Small dependency-free string/table helpers.
--
-- This exists as its own module (rather than living in utils.lua) so that
-- styles.lua can use contains() without requiring utils.lua at all, which
-- removes the utils.lua <-> styles.lua circular require that previously
-- had to be worked around with a lazy require() inside utils.lua.

-- Checks whether `item` is present in `list`, where `list` is either a Lua
-- table (array) or a comma-separated string (e.g. a user_opts value like
-- "size,color,glow").
local function contains(list, item)
    local t
    if type(list) == "table" then
        t = list
    else
        t = {}
        for str in string.gmatch(list, '([^,]+)') do
            t[#t + 1] = str:match("^%s*(.-)%s*$") -- trim spaces
        end
    end
    for _, v in ipairs(t) do
        if v == item then return true end
    end
    return false
end

return {
    contains = contains,
}
