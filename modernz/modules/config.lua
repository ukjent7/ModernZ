-- modernz :: modules/config.lua
-- User option validation.

local msg = require "mp.msg"

local core = require("modules.core")
local state = core.state
local user_opts = require("modules.options")

local _locale = require("modules.locale")
local language = _locale.language

local _constants = require("modules.constants")
local COLOR_DEFAULTS = _constants.COLOR_DEFAULTS

local function validate_user_opts()
    if not language[user_opts.language] then
       msg.warn("language '" .. user_opts.language .. "' not found. Ignoring.")
       user_opts.language = "default"
       if not language["default"] then
          msg.warn("ERROR: can't find the default language or the one set by user_opts.")
       end
    end

    if user_opts.seek_handle_size < 0 then
        msg.warn("seek_handle_size must be 0 or higher. Setting it to 0 (minimum).")
        user_opts.seek_handle_size = 0
    elseif user_opts.seek_handle_size > 1 then
        msg.warn("seek_handle_size must be 1 or lower. Setting it to 1 (maximum).")
        user_opts.seek_handle_size = 1
    end

    -- enum options that used to fall back silently on invalid values now warn and reset
    local string_opts = {
        {key = "window_top_bar",       valid = {"auto", "yes", "no"},                         default = "auto"},
        {key = "volume_control_type",  valid = {"linear", "logarithmic"},                      default = "linear"},
        {key = "keeponpause",          valid = {"no", "bottombar", "both"},                    default = "no"},
        {key = "deadzone_hide",        valid = {"instant", "timeout"},                         default = "instant"},
        {key = "icon_theme",           valid = {"fluent", "material"},                         default = "fluent"},
        {key = "icon_style",           valid = {"mixed", "filled", "outline"},                 default = "mixed"},
        {key = "layout",               valid = {"default", "compact", "mini", "seekbar"},      default = "default"},
        {key = "time_format",          valid = {"dynamic", "fixed"},                           default = "dynamic"},
        {key = "nibbles_style",        valid = {"gap", "triangle", "bar", "single-bar"},       default = "gap"},
        {key = "jump_mode",            valid = {"relative", "exact"},                          default = "relative"},
    }
    for _, opt in ipairs(string_opts) do
        local ok = false
        for _, v in ipairs(opt.valid) do
            if user_opts[opt.key] == v then ok = true break end
        end
        if not ok then
            msg.warn(opt.key .. " value '" .. tostring(user_opts[opt.key]) .. "' is invalid. Resetting to '" .. opt.default .. "'.")
            user_opts[opt.key] = opt.default
        end
    end

    local hbc = user_opts.seek_handle_border_color
    if hbc == "disable" then
        hbc = ""
    elseif hbc ~= "" and hbc:find("^#%x%x%x%x%x%x$") == nil then
        msg.warn("'" .. hbc .. "' is not a valid color for seek_handle_border_color, border disabled")
        hbc = ""
    end
    user_opts.seek_handle_border_color = hbc

    -- color options are reset to their defaults on invalid values so a typo
    -- can't leave garbage color tags in the generated ASS. The exception is
    -- seek_handle_border_color, which intentionally allows "disable"/"" and is
    -- normalized above. Defaults live in constants.COLOR_DEFAULTS.
    for key, default in pairs(COLOR_DEFAULTS) do
        local color = user_opts[key]
        if type(color) ~= "string" or color:find("^#%x%x%x%x%x%x$") == nil then
            msg.warn("'" .. tostring(color) .. "' is not a valid color for " .. key .. ". Resetting to '" .. default .. "'.")
            user_opts[key] = default
        end
    end

    -- surface unknown hover_effect tokens instead of silently ignoring them
    for token in string.gmatch(user_opts.hover_effect, "([^,]+)") do
        local t = token:match("^%s*(.-)%s*$")
        if t ~= "size" and t ~= "color" and t ~= "glow" and t ~= "box" then
            msg.warn("Ignoring unknown hover_effect '" .. t .. "'")
        end
    end

    state.visibility_modes = {}
    for str in string.gmatch(user_opts.visibility_modes, "([^_]+)") do
        if str ~= "auto" and str ~= "always" and str ~= "never" then
            msg.warn("Ignoring unknown visibility mode '" .. str .."' in list")
        else
            table.insert(state.visibility_modes, str)
        end
    end

    if user_opts.keeponpause ~= "no" and not user_opts.showonpause then
        msg.warn("keeponpause requires showonpause. Setting showonpause=yes.")
        user_opts.showonpause = true
    end

    -- sub_margins/osd_margins temporarily rewrite sub-pos/osd-margin-y while the
    -- OSC is shown. mpv's default watch-later-options include both (0.36+), so a
    -- raised value could leak into the watch_later file and keep the subtitle
    -- suspended above the bottom on the next session. Strip them from the
    -- save/restore list here so no mpv.conf workaround is needed: the script
    -- always restores the user's real value itself.
    local function strip_watch_later(option)
        local list = mp.get_property("options/watch-later-options") or ""
        local tokens, n = {}, 0
        for tok in list:gmatch("[^,]+") do
            if tok ~= option then
                n = n + 1
                tokens[n] = tok
            end
        end
        mp.set_property("options/watch-later-options", table.concat(tokens, ","))
    end
    if user_opts.sub_margins then strip_watch_later("sub-pos") end
    if user_opts.osd_margins then strip_watch_later("osd-margin-y") end
end

return {
    validate_user_opts = validate_user_opts,
}
