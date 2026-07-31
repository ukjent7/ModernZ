-- modernz :: modules/core.lua
-- Minimal shared runtime state + event bus for loose module coupling.
-- Module-owned data (icons, styles, locale, elements, layouts, etc.) lives
-- in their respective modules, not here.

local user_opts = require("modules.options")

-- OSC layout parameters (calculated by osc_init, read by rendering/utils/layouts)
local osc_param = {
    playresy = 0,
    playresx = 0,
    display_aspect = 1,
    unscaled_y = 0,
    areas = {},
    video_margins = {
        l = 0, r = 0, t = 0, b = 0,
    },
}

-- Thumbfast thumbnail state (updated via script-message, read by rendering/events)
local thumbfast = {
    width = 0,
    height = 0,
    disabled = true,
    available = false,
}

-- Shared runtime state — only genuinely cross-module runtime fields belong here.
-- Module-owned configuration/data (icons, styles, locale, elements, etc.) is
-- kept private in each owning module and accessed via accessor functions.
local state = {
    showtime = nil,
    wc_showtime = nil,
    wc_anistart = nil,
    wc_anitype = nil,
    wc_animation = nil,
    touchtime = nil,
    touchpoints = {},
    osc_visible = false,
    wc_visible = false,
    anistart = nil,
    anitype = nil,
    animation = nil,
    mouse_down_counter = 0,
    active_element = nil,
    active_event_source = nil,
    tc_left_rem = not user_opts.timecurrent,
    tc_ms = user_opts.timems,
    screen_sizeX = nil, screen_sizeY = nil,
    initREQ = false,
    marginsREQ = false,
    last_mouseX = nil, last_mouseY = nil,
    last_touchX = -1, last_touchY = -1,
    mouse_in_window = false,
    fullscreen = false,
    tick_timer = nil,
    tick_last_time = 0,
    hide_timer = nil,
    demuxer_cache_state = nil,
    idle_active = false,
    audio_track_count = 0,
    sub_track_count = 0,
    playlist_count = 0,
    playlist_pos_1 = 0,
    pause = false,
    volume = 0,
    mute = false,
    osd_dimensions = {w = 0, h = 0, aspect = 0},
    osd_scale_by_window = false,
    file_loaded = false,
    enabled = true,
    input_enabled = true,
    showhide_enabled = false,
    windowcontrols_buttons = false,
    windowcontrols_title = false,
    windowcontrols_ontop = false,
    dmx_cache = 0,
    border = true,
    title_bar = true,
    window_maximized = false,
    osd = mp.create_osd_overlay("ass-events"),
    logo_osd = mp.create_osd_overlay("ass-events"),
    keeponpause_active = false,
    keeponpause_restore = nil,
    duration = nil,
    chapter_list = {},
    chapter = -1,
    visibility_modes = {},
    eof_reached = false,
    ontop = false,
    speed = 1,
    speed_menu_open = false,
    file_loop = false,
    shuffled = false,
    sliderpos = 0,
    playing_and_seeking = false,
    playtime_hour_force_init = false,
    persistent_seekbar_element = nil,
    seekbar_element = nil,
    persistent_progress_toggle = user_opts.persistent_progress,
    user_subpos = mp.get_property_number("sub-pos") or 100,
    osc_adjusted_subpos = nil,
    is_image = false,
    is_url = false,
    url_path = "",
    downloaded_once = false,
    downloading = false,
    file_size_normalized = nil,
    title_max_w = nil,
    windowtitle_max_w = nil,
    chapter_title_max_w = nil,
}

return {
    state = state,
    osc_param = osc_param,
    thumbfast = thumbfast,
}