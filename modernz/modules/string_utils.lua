-- modernz :: modules/string_utils.lua
-- Zero-dependency string/table helpers shared across modules. Kept separate
-- from utils.lua so that low-level modules (styles/icons/locale) can use these
-- without pulling in utils.lua's heavier dependencies.

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

-- Replaces the contents of dst with the contents of src in place, keeping the
-- dst table reference valid. Used for module-owned tables that are rebuilt on
-- update (icons/styles/locale, thumbfast) so cached references stay alive.
local function replace_table(dst, src)
    for k in pairs(dst) do dst[k] = nil end
    for k, v in pairs(src) do dst[k] = v end
end

-- Removes the font-scale override tags (\fscx/\fscy) from an ASS style string.
-- Used for elements whose glyphs must not scale on hover.
local function strip_font_scale(style)
    return style:gsub("\\fscx%d+\\fscy%d+", "")
end

return {
    contains = contains,
    replace_table = replace_table,
    strip_font_scale = strip_font_scale,
}
