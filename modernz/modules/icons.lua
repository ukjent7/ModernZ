-- modernz :: modules/icons.lua
-- Icons are module-owned data, accessed via get_icons() rather than a shared table.

local user_opts = require("modules.options")

local _constants = require("modules.constants")
local icon_font = _constants.icon_font

local icon_themes = {
    fluent   = { prefix = "fluent_"   },
    material = { prefix = "material_" },
}

-- Private icon table, rebuilt by set_icon_theme()
local icons = {}

local function build_icons(theme_name, style)
    local theme = icon_themes[theme_name] or icon_themes["fluent"]
    local p = theme.prefix

    local filled_suffix  = (style ~= "outline") and "_filled" or ""
    local outline_suffix = (style == "filled")  and "_filled" or ""

    local function f(name) return p .. name .. filled_suffix  end
    local function o(name) return p .. name .. outline_suffix end

    return {
        iconfont = icon_font,
        window = {
            maximize   = "window_maximize",
            unmaximize = "window_unmaximize",
            minimize   = "window_minimize",
            close      = "window_close",
        },

        play     = f("play_arrow"),
        pause    = f("pause"),
        replay   = f("replay"),
        previous = f("skip_previous"),
        next     = f("skip_next"),
        rewind   = f("fast_rewind"),
        forward  = f("fast_forward"),
        jump = {
            [5]     = { f("replay_5"),   f("forward_5")   },
            [10]    = { f("replay_10"),  f("forward_10")  },
            [30]    = { f("replay_30"),  f("forward_30")  },
            default = { f("skip_back"),  f("skip_forward") },
        },

        audio        = o("surround_sound"),
        subtitle     = o("subtitles"),
        playlist     = o("playlist_play"),
        menu         = o("more_vert"),
        volume_mute  = o("no_sound"),
        volume_quiet = o("volume_mute"),
        volume_low   = o("volume_down"),
        volume_high  = o("volume_up"),

        download        = o("download"),
        downloading     = o("downloading"),
        speed           = o("speed"),
        shuffle_on      = o("shuffle_on"),
        shuffle_off     = o("shuffle"),
        loop_on         = o("repeat_on"),
        loop_off        = o("repeat"),
        screenshot      = o("photo_camera"),
        ontop_on        = o("pip"),
        ontop_off       = o("pip_exit"),
        info            = o("info"),
        fullscreen      = o("fullscreen"),
        fullscreen_exit = o("fullscreen_exit"),

        zoom_in         = o("zoom_in"),
        zoom_out        = o("zoom_out"),
    }
end

local function set_icon_theme()
    local _ic = build_icons(user_opts.icon_theme, user_opts.icon_style)
    for k in pairs(icons) do icons[k] = nil end
    for k, v in pairs(_ic) do icons[k] = v end
end

-- Accessor: returns the private icons table (read-only by convention).
local function get_icons()
    return icons
end

return {
    set_icon_theme = set_icon_theme,
    get_icons = get_icons,
}