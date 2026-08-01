-- modernz :: modules/osc_init.lua
-- Element definition factory + canvas initialization.

local msg = require "mp.msg"
local utils = require "mp.utils"

local core = require("modules.core")
local state = core.state
local osc_param = core.osc_param
local reset_video_margins = core.reset_video_margins

local user_opts = require("modules.options")

local _string_utils = require("modules.string_utils")
local contains = _string_utils.contains
local _utils = require("modules.utils")
local estimate_text_width = _utils.estimate_text_width
local cache_enabled = _utils.cache_enabled
local set_volume = _utils.set_volume
local window_controls_enabled = _utils.window_controls_enabled
local format_time = _utils.format_time
local build_cache_seek_ranges = _utils.build_cache_seek_ranges
local clear_text_width_cache = _utils.clear_text_width_cache
local _geometry_utils = require("modules.geometry_utils")
local get_slider_value = _geometry_utils.get_slider_value
local _margin_utils = require("modules.margin_utils")
local update_margins = _margin_utils.update_margins
local request_init = core.request_init
local _styles = require("modules.styles")
local osc_color_convert = _styles.osc_color_convert
local osc_styles = _styles.get_osc_styles()
local _icons = require("modules.icons")
local icons = _icons.get_icons()
local _locale = require("modules.locale")
local locale = _locale.get_locale()
local _elements = require("modules.elements")
local new_element = _elements.new_element
local prepare_elements = _elements.prepare_elements
local get_elements = _elements.get_elements
local clear_elements = _elements.clear_elements
local _media = require("modules.media")
local get_ytdl_format = _media.get_ytdl_format
local get_ytdl_binary = _media.get_ytdl_binary
local exec = _media.exec
local download_done = _media.download_done
local _layouts = require("modules.layouts")
local window_controls = _layouts.window_controls
local get_speed_presets = _layouts.get_speed_presets
local toggle_speed_menu = _layouts.toggle_speed_menu
local close_speed_menu = _layouts.close_speed_menu
local get_layouts = _layouts.get_layouts
local _constants = require("modules.constants")
local UNICODE_MINUS = _constants.UNICODE_MINUS

-- Module-owned tables are rebuilt in place (see elements.lua), so these
-- references stay valid across osc_init rebuilds.
local elements = get_elements()
local layouts = get_layouts()

-- Cache of escaped title strings keyed by source template. expand-text +
-- escape-ass are two command_native calls that would otherwise run on every
-- render tick; the cache is invalidated when media-title changes (the dynamic
-- part of the default "${media-title}" template) and never goes stale for
-- windowtitle, whose source is the current title property itself.
local escaped_title_cache = {}
mp.observe_property("media-title", "string", function()
    for k in pairs(escaped_title_cache) do escaped_title_cache[k] = nil end
end)

-- Expand an mpv property template and ASS-escape it. Empty results fall back
-- to "mpv" so the title bar never shows a blank label.
local function make_escaped_title(source)
    local cached = escaped_title_cache[source]
    if cached ~= nil then return cached end
    local title = mp.command_native({"expand-text", source})
    title = title:gsub("\n", " ")
    local result = title ~= "" and mp.command_native({"escape-ass", title}) or "mpv"
    escaped_title_cache[source] = result
    return result
end

-- Truncate a UTF-8 string to fit max_w (measured in style), appending an
-- ellipsis. Uses binary search over character boundaries so it never slices a
-- multi-byte character in half. Note: only called during osc_init (reinit),
-- not on the render hot path, and estimate_text_width caches per measured
-- string, so the ~log2(n) measurements are cheap in practice. A precomputed
-- character-width array would trade that for n measurements, which is worse
-- for long titles — the binary search stays (see CODE_REVIEW 5.3).
local function truncate_title(title, max_w, style)
    if not max_w or max_w <= 0 or estimate_text_width(title, style) <= max_w then return title end
    local ell_w = estimate_text_width("…", style)
    -- map each UTF-8 character to its last byte offset (avoids slicing mid-char)
    local char_ends, pos = {}, 1
    while pos <= #title do
        local b = title:byte(pos)
        local char_len = b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
        char_ends[#char_ends + 1] = pos + char_len - 1
        pos = pos + char_len
    end
    -- binary search over character count
    local low, high, fit = 1, #char_ends, 0
    while low <= high do
        local mid = math.floor((low + high) / 2)
        if estimate_text_width(title:sub(1, char_ends[mid]), style) <= max_w - ell_w then
            fit = mid; low = mid + 1
        else
            high = mid - 1
        end
    end
    return title:sub(1, fit > 0 and char_ends[fit] or 0) .. "…"
end

-- Track tooltip labels are built from mpv properties ("current-tracks/...",
-- aid/sid); recomputing them on every hovered frame costs 2-3 native property
-- reads. Cache per (label, track type, count) and invalidate when the
-- underlying tracks change (see CODE_REVIEW 5.2): aid/sid switches clear the
-- cache directly, and whole track-list changes go through request_init ->
-- osc_init(), which clears it too.
local track_tooltip_cache = {}
local function clear_track_tooltip_cache()
    for k in pairs(track_tooltip_cache) do track_tooltip_cache[k] = nil end
end
mp.observe_property("aid", "native", clear_track_tooltip_cache)
mp.observe_property("sid", "native", clear_track_tooltip_cache)

-- Track tooltip label, e.g. "Audio [1/2] [English]".
local function track_tooltip(label, track_type, id_prop, count)
    local key = label .. "|" .. track_type .. "|" .. tostring(count)
    local cached = track_tooltip_cache[key]
    if cached then return cached end
    local prop = mp.get_property("current-tracks/" .. track_type .. "/title") or mp.get_property("current-tracks/" .. track_type .. "/lang") or locale.unknown
    local result = label .. " [" .. mp.get_property_number(id_prop, "-") .. "/" .. count .. "] [" .. prop .. "]"
    track_tooltip_cache[key] = result
    return result
end

-- Step the video zoom by delta, clamped to the configured range.
local function zoom_step(delta)
    local z = mp.get_property_number("video-zoom", 0)
    mp.commandv("osd-msg", "set", "video-zoom", math.max(user_opts.zoom_out_min, math.min(user_opts.zoom_in_max, z + delta)))
end

-- Snap a speed value to 0.25 steps, clamped to the slider range.
local function snap_speed(v)
    v = math.floor(v / 0.25 + 0.5) * 0.25
    return math.max(0.05, math.min(10, v))
end

-- Adjust speed by a fine delta (0.05 steps), clamped to the slider range.
local function adjust_speed(delta)
    local spd = mp.get_property_number("speed", 1) + delta
    spd = math.floor(spd / 0.05 + 0.5) * 0.05
    spd = math.max(0.05, math.min(10, spd))
    mp.set_property_number("speed", spd)
end

-- Build a window-control button (close/minimize/maximize). They share the same
-- hover-box geometry; only icon, hover color and click action differ.
local function make_window_button(name, icon, hover_color, onclick)
    local ne = new_element(name, "button")
    ne.hover_color = hover_color
    ne.hover_radius = 0
    ne.hover_pad = 0
    ne.content = icon
    ne.eventresponder["mbtn_left_up"] = onclick
end

-- Standard "drag" handler for sliders. apply(element, pos) maps a mouse
-- position to a value (pure); set is only invoked when the value actually
-- changed (lastseek dedup), matching the original per-slider handlers.
-- reset_fn may clear extra drag state (e.g. mbtnleft) alongside lastseek.
local function make_slider_drag(element, apply, set, reset_fn)
    element.eventresponder["mouse_move"] = function(e)
        local v = apply(e, get_slider_value(e))
        if v ~= nil and (e.state.lastseek == nil or e.state.lastseek ~= v) then
            set(v)
            e.state.lastseek = v
        end
    end
    element.eventresponder["reset"] = function(e)
        e.state.lastseek = nil
        if reset_fn then reset_fn(e) end
    end
end

-- Finish a seekbar drag: release the button and unpause if the drag paused
-- playback (and it wasn't already paused when the drag started).
local function end_seek_drag(element)
    element.state.mbtnleft = false
    if state.playing_and_seeking then
        -- only unpause if the video was playing before the drag started
        if not element.state.was_paused and not mp.get_property_bool("eof-reached") and user_opts.mouse_seek_pause then
            mp.commandv("cycle", "pause")
        end
        state.playing_and_seeking = false
    end
end

local function seekbar_posF()
    if state.eof_reached then return 100 end
    return mp.get_property_number("percent-pos")
end

local function seekbar_enabled()
    return mp.get_property("percent-pos") ~= nil
end

-- Whether a user-customized mouse command exists for this element/button.
local function has_custom_cmd(element_name, button)
    local command = user_opts[element_name .. "_" .. button .. "_command"]
    return command ~= nil and command ~= "" and command ~= "ignore"
end

local function bind_buttons(element_name, use_down)
    local ev = use_down and "_down" or "_up"
    local function bind(button, event)
        if has_custom_cmd(element_name, button) then
            local command = user_opts[element_name .. "_" .. button .. "_command"]
            elements[element_name].eventresponder[event] = function() mp.command(command) end
        end
    end
    for _, b in ipairs({"mbtn_left", "mbtn_right"}) do bind(b, b .. ev) end
    bind("mbtn_mid", "shift+mbtn_left_down")
    for _, b in ipairs({"wheel_up", "wheel_down"}) do bind(b, b .. "_press") end
end

--
-- Element creation factories. osc_init() was a ~580-line function; the
-- element groups are now built by per-concern factories so each element's
-- creation logic stays easy to locate (see CODE_REVIEW 7.7). Each factory
-- owns its local `ne`; element creation order is irrelevant (layouts run
-- after all factories).
--

local function create_window_control_buttons()
    -- Window controls
    -- Close: 🗙
    make_window_button("close", icons.window.close, user_opts.windowcontrols_close_hover, function() mp.commandv("quit") end)
    -- Minimize: 🗕
    make_window_button("minimize", icons.window.minimize, user_opts.windowcontrols_min_hover, function() mp.commandv("cycle", "window-minimized") end)
    -- Maximize: 🗖/🗗
    make_window_button("maximize",
        function() return (state.window_maximized or state.fullscreen) and icons.window.unmaximize or icons.window.maximize end,
        user_opts.windowcontrols_max_hover,
        function() mp.commandv("cycle", (state.fullscreen and "fullscreen" or "window-maximized")) end)

    -- Window Title
    local ne = new_element("windowtitle", "button")
    ne.content = function()
        local t = make_escaped_title(mp.get_property("title"))
        return user_opts.truncate_title and truncate_title(t, state.windowtitle_max_w, osc_styles.window_title) or t
    end
end

local function create_title_elements()
    -- OSC title
    local ne = new_element("title", "button")
    ne.content = function()
        local t = make_escaped_title(user_opts.title)
        return user_opts.truncate_title and truncate_title(t, state.title_max_w, osc_styles.title) or t
    end
    bind_buttons("title")

    -- Chapter title
    ne = new_element("chapter_title", "button")
    ne.content = function()
        local chapter_index = state.chapter or -1
        if user_opts.chapter_fmt == "no" or chapter_index < 0 then return "" end
        local chapter_data = state.chapter_list[chapter_index + 1]
        local chapter_title = mp.command_native({"escape-ass",
            chapter_data and chapter_data.title ~= "" and chapter_data.title
            or string.format("%s: %d/%d", locale.chapter, chapter_index + 1, #state.chapter_list)})
        local t = string.format(user_opts.chapter_fmt, chapter_title)
        return user_opts.truncate_title and truncate_title(t, state.chapter_title_max_w, osc_styles.chapter_title) or t
    end
    bind_buttons("chapter_title")
end

local function create_playback_controls()
    local pl_count = state.playlist_count
    local have_pl = pl_count > 1
    local pl_pos = state.playlist_pos_1
    local have_ch = #state.chapter_list > 0
    local loop = mp.get_property("loop-playlist", "no")
    local jump_amount = user_opts.jump_amount
    local jump_more_amount = user_opts.jump_more_amount
    local jump_mode = user_opts.jump_mode
    local jump_icon = user_opts.jump_icon_number and icons.jump[jump_amount] or icons.jump.default

    -- playlist buttons
    -- prev
    local ne = new_element("playlist_prev", "button")
    ne.content = icons.previous
    ne.enabled = (pl_pos > 1) or (loop ~= "no") or contains(user_opts.buttons_always_active, "playlist_prev")
    bind_buttons("playlist_prev")

    --next
    ne = new_element("playlist_next", "button")
    ne.content = icons.next
    ne.enabled = (have_pl and (pl_pos < pl_count)) or (loop ~= "no") or contains(user_opts.buttons_always_active, "playlist_next")
    bind_buttons("playlist_next")

    --play control buttons
    --play_pause
    ne = new_element("play_pause", "button")
    ne.content = function() return state.eof_reached and icons.replay or (state.pause and not state.playing_and_seeking and icons.play) or icons.pause end
    bind_buttons("play_pause")
    ne.eventresponder["mbtn_left_up"] = function()
        if state.eof_reached then
            mp.commandv("seek", 0, "absolute-percent")
            mp.commandv("set", "pause", "no")
        else
            mp.command(user_opts.play_pause_mbtn_left_command)
        end
    end

    --jump_backward
    ne = new_element("jump_backward", "button")
    ne.softrepeat = user_opts.jump_softrepeat
    ne.content = jump_icon[1]
    ne.eventresponder["mbtn_left_down"] = function() mp.commandv("seek", -jump_amount, jump_mode) end
    ne.eventresponder["mbtn_right_down"] = function() mp.commandv("seek", -jump_more_amount, jump_mode) end
    ne.eventresponder["shift+mbtn_left_down"] = function() mp.commandv("frame-back-step") end

    --jump_forward
    ne = new_element("jump_forward", "button")
    ne.softrepeat = user_opts.jump_softrepeat
    ne.content = jump_icon[2]
    ne.eventresponder["mbtn_left_down"] = function() mp.commandv("seek", jump_amount, jump_mode) end
    ne.eventresponder["mbtn_right_down"] = function() mp.commandv("seek", jump_more_amount, jump_mode) end
    ne.eventresponder["shift+mbtn_left_down"] = function() mp.commandv("frame-step") end

    --chapter_prev
    ne = new_element("chapter_prev", "button")
    ne.content = icons.rewind
    ne.enabled = have_ch -- disables button when no chapters available.
    bind_buttons("chapter_prev", true)

    --chapter_next
    ne = new_element("chapter_next", "button")
    ne.content = icons.forward
    ne.enabled = have_ch -- disables button when no chapters available.
    bind_buttons("chapter_next", true)
end

local function create_track_buttons()
    local pl_count = state.playlist_count
    local have_pl = pl_count > 1
    local pl_pos = state.playlist_pos_1

    --playlist
    local ne = new_element("playlist", "button")
    ne.enabled = have_pl or not user_opts.hide_empty_playlist_button
    ne.off = not have_pl and user_opts.gray_empty_playlist_button
    ne.content = icons.playlist
    ne.tooltipF = function() return have_pl and locale.playlist .. " [" .. pl_pos .. "/" .. pl_count .. "]" or locale.playlist .. " / " .. locale.menu end
    ne.nothingavailable = locale.no_playlist
    bind_buttons("playlist")

    --audio_track
    ne = new_element("audio_track", "button")
    ne.enabled = state.audio_track_count > 0
    ne.off = state.audio_track_count == 0 or not mp.get_property_native("aid")
    ne.content = icons.audio
    ne.tooltipF = function() return track_tooltip(locale.audio, "audio", "aid", state.audio_track_count) end
    ne.nothingavailable = locale.no_audio
    bind_buttons("audio_track")

    --sub_track
    ne = new_element("sub_track", "button")
    ne.enabled = state.sub_track_count > 0
    ne.off = state.sub_track_count == 0 or not mp.get_property_native("sid")
    ne.content = icons.subtitle
    ne.tooltipF = function() return track_tooltip(locale.subtitle, "sub", "sid", state.sub_track_count) end
    ne.nothingavailable = locale.no_subs
    bind_buttons("sub_track")
end

local function create_volume_controls()
    -- vol_ctrl
    local ne = new_element("vol_ctrl", "button")
    ne.enabled = state.audio_track_count > 0
    ne.off = state.audio_track_count == 0
    ne.content = function()
        local volume = state.volume
        return state.mute and icons.volume_mute or (volume >= 75 and icons.volume_high) or (volume >= 25 and icons.volume_low) or icons.volume_quiet
    end
    ne.tooltipF = function()
        local volume = state.volume
        -- show only one decimal, if decimals exist
        local volume_str = (volume % 1 == 0) and string.format("%.0f", volume) or string.format("%.1f", volume)
        return locale.volume .. ": " .. volume_str .. (state.mute and " (" .. locale.muted .. ")" or "")
    end
    bind_buttons("vol_ctrl")

    --volumebar
    local volume_max_prop = mp.get_property_number("volume-max") or 0
    local volume_max = volume_max_prop > 0 and volume_max_prop or 100
    ne = new_element("volumebar", "slider")
    ne.enabled = state.audio_track_count > 0
    -- mutate the default slider table so markerF/seekRangesF defaults survive
    ne.slider.min.value = 0
    ne.slider.max.value = volume_max
    ne.slider.posF = function()
        if user_opts.volume_control_type ~= "logarithmic" then return state.volume end
        return state.volume and math.sqrt(state.volume * 100) or 0
    end
    make_slider_drag(ne, function(_, pos)
        return set_volume(pos)
    end, function(v)
        mp.commandv("set", "volume", v)
    end, function(e) e.state.mbtnleft = false end)
    ne.eventresponder["mbtn_left_down"] = function(element)
        element.state.mbtnleft = true
        local pos = get_slider_value(element)
        if user_opts.volumebar_unmute_on_click then
            mp.set_property_bool("mute", false)
        end
        mp.commandv("set", "volume", set_volume(pos))
    end
    ne.eventresponder["mbtn_left_up"] = function(element)
        element.state.mbtnleft = false
        element.state.handle_drag = false
    end
    bind_buttons("volumebar")
end

local function create_zoom_controls()
    -- zoom out icon
    local ne = new_element("zoom_out_icon", "button")
    ne.content = icons.zoom_out
    ne.tooltipF = locale.zoom_out
    ne.eventresponder["mbtn_left_up"] = function() zoom_step(-0.05) end
    ne.eventresponder["mbtn_right_up"] = function() mp.commandv("osd-msg", "set", "video-zoom", 0) end
    ne.eventresponder["wheel_up_press"] = function() zoom_step(0.05) end
    ne.eventresponder["wheel_down_press"] = function() zoom_step(-0.05) end

    -- zoom slider
    ne = new_element("zoom_control", "slider")
    ne.slider.min.value = user_opts.zoom_out_min
    ne.slider.max.value = user_opts.zoom_in_max
    ne.slider.posF = function() return mp.get_property_number("video-zoom") end
    ne.slider.tooltipF = function(pos) return string.format("%.3f", pos):gsub("%.?0*$", "") end
    make_slider_drag(ne, function(_, pos)
        return pos
    end, function(v)
        mp.commandv("osd-msg", "set", "video-zoom", v)
    end)
    ne.eventresponder["mbtn_left_down"] = function(element) mp.commandv("osd-msg", "set", "video-zoom", get_slider_value(element)) end
    ne.eventresponder["mbtn_right_up"] = function() mp.commandv("osd-msg", "set", "video-zoom", 0) end
    ne.eventresponder["wheel_up_press"] = function() zoom_step(0.05) end
    ne.eventresponder["wheel_down_press"] = function() zoom_step(-0.05) end

    -- zoom in icon
    ne = new_element("zoom_in_icon", "button")
    ne.content = icons.zoom_in
    ne.tooltipF = locale.zoom_in
    ne.eventresponder["mbtn_left_up"] = function() zoom_step(0.05) end
    ne.eventresponder["mbtn_right_up"] = function() mp.commandv("osd-msg", "set", "video-zoom", 0) end
    ne.eventresponder["wheel_up_press"] = function() zoom_step(0.05) end
    ne.eventresponder["wheel_down_press"] = function() zoom_step(-0.05) end
end

local function create_side_buttons()
    --fullscreen
    local ne = new_element("fullscreen", "button")
    ne.content = function() return state.fullscreen and icons.fullscreen_exit or icons.fullscreen end
    ne.tooltipF = function() return state.fullscreen and locale.fullscreen_exit or locale.fullscreen end
    bind_buttons("fullscreen")

    --info
    ne = new_element("info", "button")
    ne.content = icons.info
    ne.tooltipF = locale.stats_info
    bind_buttons("info")

    --ontop
    ne = new_element("ontop", "button")
    ne.content = function() return not state.ontop and icons.ontop_on or icons.ontop_off end
    ne.tooltipF = function()
        if user_opts.ontop_in_topbar and window_controls_enabled() and state.ontop then return nil end
        return state.ontop and locale.ontop_disable or locale.ontop
    end
    bind_buttons("ontop")

    --screenshot
    ne = new_element("screenshot", "button")
    ne.content = icons.screenshot
    ne.tooltipF = locale.screenshot
    bind_buttons("screenshot")

    --file_loop
    ne = new_element("file_loop", "button")
    ne.content = function() return state.file_loop and icons.loop_on or icons.loop_off end
    ne.tooltipF = function() return state.file_loop and locale.file_loop_enable or locale.file_loop_disable end
    bind_buttons("file_loop")

    --shuffle
    ne = new_element("shuffle", "button")
    ne.content = function() return state.shuffled and icons.shuffle_on or icons.shuffle_off end
    ne.tooltipF = function() return state.shuffled and locale.shuffle or locale.unshuffle end
    ne.eventresponder["mbtn_left_up"] = function()
        mp.commandv("show-text", state.shuffled and locale.unshuffle or locale.shuffle, "-1", "1")
        state.shuffled = not state.shuffled
        mp.command("playlist-" .. (state.shuffled and "shuffle" or "unshuffle"))
    end

    --speed
    ne = new_element("speed", "button")
    ne.content = function() return string.format(state.speed % 1 == 0 and "%.1f×" or "%g×", state.speed) end
    ne.tooltipF = locale.speed_control
    bind_buttons("speed")
    -- override left click to toggle speed menu
    ne.eventresponder["mbtn_left_up"] = function() toggle_speed_menu() end

    --download
    ne = new_element("download", "button")
    ne.content = function() return state.downloading and icons.downloading or icons.download end
    ne.tooltipF = function() return state.downloading and locale.downloading .. "..." or locale.download .. " (" .. state.file_size_normalized .. ")" end
    ne.eventresponder["mbtn_left_up"] = function()
        local localpath = mp.command_native({"expand-path", user_opts.download_path})

        if state.downloaded_once then
            mp.commandv("show-text", locale.downloaded, "-1", "1")
        elseif state.downloading then
            mp.commandv("show-text", locale.download_in_progress, "-1", "1")
        else
            mp.commandv("show-text", locale.downloading .. "...", "-1", "1")
            state.downloading = true
            local command = {
                get_ytdl_binary(),
                state.is_image and "" or get_ytdl_format(),
                "--add-metadata",
                "--embed-subs",
                "-o", "%(title)s.%(ext)s",
                "-P", localpath,
                state.url_path
            }

            exec(command, download_done)
        end
    end

    -- cache info
    ne = new_element("cache_info", "button")
    ne.content = function()
        if not cache_enabled() then return "" end
        local dcs = state.demuxer_cache_state
        local dmx_cache = state.dmx_cache
        local cache_state = dcs and dcs["cache-duration"]
        local thresh = math.min(dmx_cache * 0.05, 5)
        if cache_state and math.abs(cache_state - dmx_cache) >= thresh then
            dmx_cache = cache_state
            state.dmx_cache = cache_state
        end
        local min = math.floor(dmx_cache / 60)
        local sec = math.floor(dmx_cache % 60)
        local cache_time = (min > 0) and string.format("%sm%02ds", min, sec) or string.format("%3ds", sec)
        local cache_info = (mp.get_property_bool("paused-for-cache") == true) and (locale.buffering .. ": " .. (mp.get_property("cache-buffering-state") or 0) .. "%") or cache_time
        if not user_opts.cache_info_speed then return cache_info end
        local dmx_speed = (dcs and dcs["raw-input-rate"]) or 0
        local number, unit = utils.format_bytes_humanized(dmx_speed):match("([%d%.]+)%s*(%S+)")
        return cache_info .. "\\N" .. string.format("%8s %4s/s", number or 0, unit or "B")
    end
    ne.tooltipF = function() return cache_enabled() and locale.cache or nil end
    ne.eventresponder["mbtn_left_up"] = function() mp.command("script-binding stats/display-page-3") end
end

local function create_speed_menu_elements()
    --speed menu backdrop (click outside to close)
    local ne = new_element("speed_menu_backdrop", "button")
    ne.content = ""
    ne.visible = false
    ne.eventresponder["mbtn_left_up"] = function() close_speed_menu() end

    --speed menu background panel
    ne = new_element("speed_menu_bg", "box")
    ne.visible = false

    --speed menu title (non-interactive label)
    ne = new_element("speed_menu_title", "button")
    ne.content = function() return locale.speed_control end
    ne.visible = false

    --speed menu big current speed readout (non-interactive)
    ne = new_element("speed_menu_value", "button")
    ne.content = function()
        local spd = mp.get_property_number("speed", 1)
        return string.format("%.2f", spd):gsub("%.?0+$", "") .. "×"
    end
    ne.visible = false

    --speed slider track background
    ne = new_element("speed_slider_bg", "box")
    ne.visible = false

    --speed slider (0.05x - 10x, snaps to 0.25 steps)
    ne = new_element("speed_slider", "slider")
    ne.visible = false
    ne.slider.min.value = 0.05
    ne.slider.max.value = 10
    ne.slider.posF = function() return mp.get_property_number("speed", 1) end
    ne.eventresponder["mbtn_left_down"] = function(element)
        element.state.mbtnleft = true
        mp.set_property_number("speed", snap_speed(get_slider_value(element)))
    end
    make_slider_drag(ne, function(e, pos)
        if not e.state.mbtnleft then return nil end
        return snap_speed(pos)
    end, function(v)
        mp.set_property_number("speed", v)
    end, function(e) e.state.mbtnleft = false end)
    ne.eventresponder["mbtn_left_up"] = function(element)
        element.state.mbtnleft = false
        element.state.lastseek = nil
    end

    --speed decrease button
    ne = new_element("speed_dec", "button")
    ne.content = "-"
    ne.visible = false
    ne.eventresponder["mbtn_left_up"] = function() adjust_speed(-0.05) end

    --speed increase button
    ne = new_element("speed_inc", "button")
    ne.content = "+"
    ne.visible = false
    ne.eventresponder["mbtn_left_up"] = function() adjust_speed(0.05) end

    --speed preset buttons (active one is highlighted in the accent color)
    local speed_presets = get_speed_presets()
    for i, spd in ipairs(speed_presets) do
        ne = new_element("speed_preset_" .. i, "button")
        ne.content = function()
            local is_active = math.abs(state.speed - spd) < 0.001
            local label = string.format("%g", spd)
            return is_active and ("{\\1c&H" .. osc_color_convert(user_opts.seekbarfg_color) .. "&\\b1}" .. label) or ("{\\1c&HCCCCCC&}" .. label)
        end
        ne.visible = false
        ne.speed_value = spd
        ne.eventresponder["mbtn_left_up"] = function()
            mp.set_property_number("speed", spd)
        end
    end
end

local function create_seekbar_elements()
    --seekbar
    local ne = new_element("seekbar", "slider")
    ne.enabled = seekbar_enabled()
    ne.thumbnailable = true
    ne.slider.markerF = function()
        if state.duration then
            local chapters = state.chapter_list
            local markers = {}
            for n = 1, #chapters do
                markers[n] = (chapters[n].time / state.duration * 100)
            end
            return markers
        else
            return {}
        end
    end
    ne.slider.posF = seekbar_posF
    ne.slider.tooltipF = function(pos)
        if state.duration ~= nil and pos ~= nil then return format_time(state.duration * (pos / 100)) end
        return ""
    end
    ne.slider.seekRangesF = build_cache_seek_ranges
    ne.eventresponder["mouse_move"] = function(element)
        if not element.state.mbtnleft then return end -- allow drag for mbtnleft only!
        state.playing_and_seeking = true
        if not mp.get_property_bool("pause") and user_opts.mouse_seek_pause then
            mp.commandv("cycle", "pause")
        end
        local seekto = get_slider_value(element)
        if element.state.lastseek == nil or element.state.lastseek ~= seekto then
            local flags = "absolute-percent"
            if not user_opts.seekbarkeyframes then
                flags = flags .. "+exact"
            end
            mp.commandv("seek", seekto, flags)
            element.state.lastseek = seekto
        end
    end
    ne.eventresponder["mbtn_left_down"] = function(element)
        element.state.mbtnleft = true
        element.state.was_paused = mp.get_property_bool("pause")
        state.playing_and_seeking = false
        mp.commandv("seek", get_slider_value(element), "absolute-percent+exact")
    end
    ne.eventresponder["shift+mbtn_left_down"] = function(element)
        element.state.mbtnleft = true
        element.state.was_paused = mp.get_property_bool("pause")
        state.playing_and_seeking = false
        mp.commandv("seek", get_slider_value(element), "absolute-percent")
    end
    ne.eventresponder["mbtn_left_up"] = function(element)
        end_seek_drag(element)
    end
    ne.eventresponder["mbtn_right_down"] = function(element)
        local chapter
        local pos = get_slider_value(element)
        local diff = math.huge

        for i, marker in ipairs(element.slider.markerF()) do
            if math.abs(pos - marker) < diff then
                diff = math.abs(pos - marker)
                chapter = i
            end
        end

        if chapter then
            mp.set_property("chapter", chapter - 1)
        end
    end
    ne.eventresponder["reset"] = function(element)
        element.state.lastseek = nil
        if element.state.mbtnleft then
            end_seek_drag(element)
        end
    end
    bind_buttons("seekbar")

    --persistent seekbar
    ne = new_element("persistent_seekbar", "slider")
    ne.enabled = seekbar_enabled()
    ne.slider.posF = seekbar_posF
    ne.slider.tooltipF = function() return "" end
    ne.slider.seekRangesF = function()
        if user_opts.persistent_buffer then return build_cache_seek_ranges() end
        return nil
    end

    -- Time codes display
    ne = new_element("time_codes", "button")
    ne.content = function()
        local playback_time = mp.get_property_number("playback-time", 0)
        if not state.duration then return "--:--" end

        local playtime_remaining = state.tc_left_rem and mp.get_property_number("playtime-remaining", 0) or playback_time
        local prefix = state.tc_left_rem and (user_opts.unicodeminus and UNICODE_MINUS or "-") or ""

        -- call request_init() only when needed to update time code width
        if user_opts.time_format ~= "fixed" and playback_time then
            local hour_or_more = playback_time >= 3600
            if hour_or_more ~= state.playtime_hour_force_init then
                request_init()
                state.playtime_hour_force_init = hour_or_more
            end
        end

        return prefix .. format_time(playtime_remaining) .. " / " .. format_time(state.duration)
    end
    ne.eventresponder["mbtn_left_up"] = function()
        state.tc_left_rem = not state.tc_left_rem
        request_init()
    end
    ne.eventresponder["mbtn_right_up"] = function()
        state.tc_ms = not state.tc_ms
        request_init()
    end
end

local function osc_init()
    msg.debug("osc_init")

    -- set canvas resolution according to display aspect and scaling setting
    local baseResY = 720
    local display_h = state.osd_dimensions.h
    local display_aspect = state.osd_dimensions.aspect
    local scale

    if state.fullscreen then
        scale = user_opts.scalefullscreen
    else
        scale = user_opts.scalewindowed
    end

    local scale_with_video
    if user_opts.vidscale == "auto" then
        scale_with_video = state.osd_scale_by_window
    else
        scale_with_video = user_opts.vidscale == "yes"
    end

    if scale_with_video then
        osc_param.unscaled_y = baseResY
    else
        osc_param.unscaled_y = display_h
    end
    osc_param.playresy = osc_param.unscaled_y / scale
    if display_aspect > 0 then
        osc_param.display_aspect = display_aspect
    end
    osc_param.playresx = osc_param.playresy * osc_param.display_aspect

    -- stop seeking with the slider to prevent skipping files
    state.active_element = nil
    state.playing_and_seeking = false

    -- reset margins and text width
    clear_text_width_cache()
    reset_video_margins()

    clear_elements()
    -- tracks may have changed (this runs on every re-init, e.g. track-list
    -- updates), so drop cached track tooltip labels
    clear_track_tooltip_cache()

    -- build all elements (grouped into per-concern factories, see above)
    create_window_control_buttons()
    create_title_elements()
    create_playback_controls()
    create_track_buttons()
    create_volume_controls()
    create_zoom_controls()
    create_side_buttons()
    create_speed_menu_elements()
    create_seekbar_elements()

    -- load layout
    if state.is_image then
        layouts["modern-image"]()
    elseif layouts[user_opts.layout] then
        layouts[user_opts.layout]()
    else
        layouts["default"]()
    end

    -- load window controls (evaluate once so the layout and this gate agree)
    local wc_enabled = window_controls_enabled()
    if wc_enabled then
        window_controls()
    end

    -- cache seekbar elements
    -- Note: these name-based lookups must happen BEFORE prepare_elements(),
    -- which re-keys the elements table into a layer-sorted array and drops the
    -- name keys. The references stored here are the element objects themselves,
    -- so they stay valid after the table is re-keyed.
    state.persistent_seekbar_element = elements["persistent_seekbar"]
    state.seekbar_element = elements["seekbar"]

    prepare_elements()
    update_margins()
end

return {
    osc_init = osc_init,
}
