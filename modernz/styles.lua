-- modernz :: modules/styles.lua
-- Styles, hover effects, and seekbar height presets are module-owned data,
-- accessed via accessors rather than a shared table.

local core = require("modules.core")
local state = core.state

local user_opts = require("modules.options")

local _icons = require("modules.icons")
local _string_utils = require("modules.string_utils")
local contains = _string_utils.contains
local replace_table = _string_utils.replace_table

-- Private module-owned data
local osc_styles = {}
local hover_effects = { size = false, color = false, glow = false, box = false }
local seekbar_height_style = {}

local function osc_color_convert(color)
    return color:sub(6,7) .. color:sub(4,5) ..  color:sub(2,3)
end

local function set_osc_styles()
    local icons = _icons.get_icons()
    local playpause_size = user_opts.playpause_size
    local midbuttons_size = user_opts.midbuttons_size
    local sidebuttons_size = user_opts.sidebuttons_size

    hover_effects.size  = contains(user_opts.hover_effect, "size")
    hover_effects.color = contains(user_opts.hover_effect, "color")
    hover_effects.glow  = contains(user_opts.hover_effect, "glow")
    hover_effects.box   = contains(user_opts.hover_effect, "box")

    local seekbar_presets = {
        small  = { radius = 1, height = 2 },
        medium = { radius = 2, height = 4 },
        large  = { radius = 3, height = 6 },
        xlarge = { radius = 4, height = 8 }
    }
    local _sh = seekbar_presets[user_opts.seekbar_height] or seekbar_presets.medium
    replace_table(seekbar_height_style, _sh)

    local _os = {
        osc_fade_bg = "{\\blur" .. user_opts.fade_blur_strength .. "\\bord" .. user_opts.osc_fade_strength .. "\\1c&H0&\\3c&H" .. osc_color_convert(user_opts.osc_color) .. "&}",
        window_fade_bg = "{\\blur" .. user_opts.window_fade_blur_strength .. "\\bord" .. user_opts.window_fade_strength .. "\\1c&H0&\\3c&H" .. osc_color_convert(user_opts.osc_color) .. "&}",
        window_control = "{\\1c&H" .. osc_color_convert(user_opts.window_controls_color) .. "&\\fs25\\fn" .. icons.iconfont .. "}",
        window_title = "{\\bord1\\1c&H" .. osc_color_convert(user_opts.window_title_color) .. "&\\3c&H0&\\fs".. user_opts.window_title_font_size .."\\q2\\fn" .. user_opts.font .. "}",
        title = "{\\bord1\\1c&H" .. osc_color_convert(user_opts.title_color) .. "&\\3c&H0&\\fs".. user_opts.title_font_size .."\\q2\\fn" .. user_opts.font .. "}",
        chapter_title = "{\\bord1\\1c&H" .. osc_color_convert(user_opts.chapter_title_color) .. "&\\3c&H0&\\fs" .. user_opts.chapter_title_font_size .. "\\q2\\fn" .. user_opts.font .. "}",
        seekbar_bg = "{\\1c&H" .. osc_color_convert(user_opts.seekbarbg_color) .. "&}",
        seekbar_fg = "{\\blur1\\bord1\\1c&H" .. osc_color_convert(user_opts.seekbarfg_color) .. "&}",
        thumbnail = "{\\bord" .. user_opts.thumbnail_box_outline_size .. "\\1c&H" .. osc_color_convert(user_opts.thumbnail_box_color) .. "&\\3c&H" .. osc_color_convert(user_opts.thumbnail_box_outline) .. "&}",
        time = "{\\bord1\\1c&H" .. osc_color_convert(user_opts.time_color) .. "&\\3c&H0&\\fs" .. user_opts.time_font_size .. "\\fn" .. user_opts.font .. "}",
        cache = "{\\bord1\\1c&H" .. osc_color_convert(user_opts.cache_info_color) .. "&\\3c&H0&\\fs" .. user_opts.cache_info_font_size .. "\\fn" .. user_opts.font .. "}",
        tooltip = "{\\bord1\\1c&HFFFFFF&\\3c&H0&\\fs" .. user_opts.tooltip_font_size .. "\\fn" .. user_opts.font .. "}",
        tooltip_box = "{\\1c&H" .. osc_color_convert(user_opts.osc_color) .. "&}",
        speed = "{\\bord1\\1c&H" .. osc_color_convert(user_opts.side_buttons_color) .. "&\\3c&H0&\\fs" .. user_opts.speed_font_size .. "\\fn" .. user_opts.font .. "}",
        volumebar_bg = "{\\1c&H999999&}",
        volumebar_fg = "{\\blur1\\bord1\\1c&H" .. osc_color_convert(user_opts.side_buttons_color) .. "&}",
        control_1 = "{\\1c&H" .. osc_color_convert(user_opts.playpause_color) .. "&\\fs" .. playpause_size .. "\\fn" .. icons.iconfont .. "}",
        control_2 = "{\\1c&H" .. osc_color_convert(user_opts.middle_buttons_color) .. "&\\fs" .. midbuttons_size .. "\\fn" .. icons.iconfont .. "}",
        control_3 = "{\\1c&H" .. osc_color_convert(user_opts.side_buttons_color) .. "&\\fs" .. sidebuttons_size .. "\\fn" .. icons.iconfont .. "}",
        control_mini = "{\\1c&H" .. osc_color_convert(user_opts.side_buttons_color) .. "&\\fs16\\fn" .. icons.iconfont .. "}",
        element_down = "{\\1c&H" .. osc_color_convert(user_opts.held_element_color) .. "&" .. string.format("\\fscx%s\\fscy%s", user_opts.button_held_size, user_opts.button_held_size) .. "}",
        element_hover = "{" .. (hover_effects.color and "\\1c&H" .. osc_color_convert(user_opts.hover_effect_color) .. "&" or "") .. (hover_effects.size and string.format("\\fscx%s\\fscy%s", user_opts.button_hover_size, user_opts.button_hover_size) or "") .. "}",
        hover_bg = "{\\1c&H" .. osc_color_convert(user_opts.hover_effect_color) .. "&}",
    }
    replace_table(osc_styles, _os)
end

local function set_time_styles(timecurrent_changed, timems_changed)
    if timecurrent_changed then
        state.tc_left_rem = not user_opts.timecurrent
    end
    if timems_changed then
        state.tc_ms = user_opts.timems
    end
end

-- Accessors for module-owned data
local function get_osc_styles()
    return osc_styles
end

local function get_hover_effects()
    return hover_effects
end

local function get_seekbar_height_style()
    return seekbar_height_style
end

return {
    osc_color_convert = osc_color_convert,
    set_osc_styles = set_osc_styles,
    set_time_styles = set_time_styles,
    get_osc_styles = get_osc_styles,
    get_hover_effects = get_hover_effects,
    get_seekbar_height_style = get_seekbar_height_style,
}