-- modernz :: modules/core.lua
-- Shared runtime state + tick/init scheduling. Module-owned data (icons,
-- styles, locale, elements, layouts, etc.) lives in their own modules.

local msg = require "mp.msg"

local user_opts = require("modules.options")

-- OSC layout parameters (canvas coordinate system)
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
    file_loaded_time = nil, -- when the current file finished loading (see the "seek" handler in main.lua)
    enabled = true,
    input_enabled = true,
    showhide_enabled = false,
    windowcontrols_buttons = false,
    windowcontrols_title = false,
    windowcontrols_ontop = false,
    dmx_cache = 0,
    border = true,
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

-- Reset the video margins to zero in place (keeps the osc_param.video_margins
-- reference valid across re-inits).
local function reset_video_margins()
    osc_param.video_margins.l = 0
    osc_param.video_margins.r = 0
    osc_param.video_margins.t = 0
    osc_param.video_margins.b = 0
end

-- Whether the persistent progress line is enabled (option or runtime toggle).
local function persistent_progress_enabled()
    return user_opts.persistent_progress or state.persistent_progress_toggle
end

-- Tick/init scheduling. tick() is defined in the events module and injected
-- here at load time via set_tick(). Every entry point that needs it goes
-- through ensure_tick(), which fails loudly instead of leaving a nil passed
-- into mp.add_timeout.
local tick_delay = 1 / 60
local tick
local function set_tick(fn) tick = fn end

local function ensure_tick()
    if not tick then
        msg.error("core.lua: tick() requested before set_tick() was called - ignoring. " ..
                   "This means module load order is wrong (events.lua must call set_tick() at load time).")
        return false
    end
    return true
end

local function request_tick()
    if not ensure_tick() then return end

    if state.tick_timer == nil then
        state.tick_timer = mp.add_timeout(0, tick)
    end

    if not state.tick_timer:is_enabled() then
        local now = mp.get_time()
        local timeout = tick_delay - (now - state.tick_last_time)
        if timeout < 0 then
            timeout = 0
        end
        state.tick_timer.timeout = timeout
        state.tick_timer:resume()
    end
end

local function request_init()
    state.initREQ = true
    request_tick()
end

local function request_init_resize()
    request_init()
    if not state.tick_timer then return end
    -- ensure immediate update
    state.tick_timer:kill()
    state.tick_timer.timeout = 0
    state.tick_timer:resume()
end

local function set_tick_delay(_, display_fps)
    -- may be nil if unavailable, or 0 if a display reports 0 fps; guard both
    -- so a stale 0 can't produce tick_delay = 1/0 = inf
    if not display_fps or display_fps <= 0 or not user_opts.tick_delay_follow_display_fps then
        tick_delay = user_opts.tick_delay
        return
    end
    tick_delay = 1 / display_fps
end

return {
    state = state,
    osc_param = osc_param,
    thumbfast = thumbfast,
    reset_video_margins = reset_video_margins,
    persistent_progress_enabled = persistent_progress_enabled,
    request_tick = request_tick,
    request_init = request_init,
    request_init_resize = request_init_resize,
    set_tick_delay = set_tick_delay,
    set_tick = set_tick,
}