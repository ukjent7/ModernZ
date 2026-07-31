-- ModernZ v0.3.3 (https://github.com/Samillion/ModernZ)
--
-- This script is a derivative of the original mpv-osc-modern by maoiscat
-- and subsequent forks:
--   * cyl0/ModernX
--   * dexeonify/ModernX
--
-- It is based on the official osc.lua from mpv, licensed under the
-- GNU Lesser General Public License v2.1 (LGPLv2.1).
-- Full license: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html


local msg = require "mp.msg"
local opt = require "mp.options"
local utils = require "mp.utils"

-- Resolve the module directory so require() can find modules/*.lua
local script_dir = mp.get_script_directory()
package.path = script_dir .. "/?.lua;" .. package.path

mp.set_property("osc", "no")

local core = require("modules.core")
local state = core.state
local thumbfast = core.thumbfast
local user_opts = require("modules.options")

local _control = require("modules.control")
local request_tick = _control.request_tick
local request_init = _control.request_init
local request_init_resize = _control.request_init_resize
local set_tick_delay = _control.set_tick_delay
local _utils = require("modules.utils")
local observe_cached = _utils.observe_cached
local set_virt_mouse_area = _utils.set_virt_mouse_area
local reset_margins = _utils.reset_margins
local _styles = require("modules.styles")
local set_osc_styles = _styles.set_osc_styles
local set_time_styles = _styles.set_time_styles
local _icons = require("modules.icons")
local set_icon_theme = _icons.set_icon_theme
local _locale = require("modules.locale")
local load_locale_file = _locale.load_locale_file
local set_osc_locale = _locale.set_osc_locale
local _media = require("modules.media")
local is_image = _media.is_image
local check_path_url = _media.check_path_url
local _events = require("modules.events")
local update_tracklist = _events.update_tracklist
local osc_visible = _events.osc_visible
local wc_visible = _events.wc_visible
local show_wc = _events.show_wc
local hide_wc = _events.hide_wc
local show_osc = _events.show_osc
local hide_osc = _events.hide_osc
local mouse_leave = _events.mouse_leave
local handle_touch = _events.handle_touch
local reset_timeout = _events.reset_timeout
local process_event = _events.process_event
local do_enable_keybindings = _events.do_enable_keybindings
local visibility_mode = _events.visibility_mode
local idlescreen_visibility = _events.idlescreen_visibility
local _config = require("modules.config")
local validate_user_opts = _config.validate_user_opts

mp.register_event("shutdown", function()
    reset_margins()
    mp.del_property("user-data/osc")
end)
mp.register_event("file-loaded", function()
    is_image() -- check if file is an image
    state.file_loaded = true
    check_path_url()
    local oos = user_opts.osc_on_start
    if oos == "bottom" or oos == "both" then show_osc() end
    if oos == "top" or oos == "both" then show_wc() end
end)
mp.register_event("start-file", function()
    -- reset ab loop on new file start
    mp.set_property("ab-loop-a", "no")
    mp.set_property("ab-loop-b", "no")
    state.speed_menu_open = false
    request_init()
end)
mp.observe_property("track-list", "native", update_tracklist)
observe_cached("playlist-count", request_init)
observe_cached("playlist-pos-1", request_init)
observe_cached("chapter-list", function ()
    state.chapter_list = state.chapter_list or {}
    table.sort(state.chapter_list, function(a, b) return a.time < b.time end)
    request_init()
end)
observe_cached("duration", function ()
    if user_opts.automatickeyframemode then
        user_opts.seekbarkeyframes = (state.duration or 0) > user_opts.automatickeyframelimit
    end
    if user_opts.livemarkers and state.chapter_list[1] then
        request_init()
    end
end)
mp.register_event("seek", function()
    if state.file_loaded then
        state.file_loaded = false
        return
    end
    if user_opts.osc_on_seek and not (state.file_loop and mp.get_property_number("time-pos", -1) == 0) then
        show_osc()
    end
end)
mp.observe_property("seeking", "native", function(_, seeking)
    if user_opts.osc_on_seek then
        reset_timeout()
    end
end)
observe_cached("fullscreen", function ()
    state.marginsREQ = true
    request_init_resize()
end)
observe_cached("border", request_init_resize)
observe_cached("title-bar", request_init_resize)
observe_cached("window-maximized", request_init_resize)
observe_cached("idle-active", request_tick)
mp.observe_property("user-data/mpv/console/open", "bool", function(_, val)
    if val and user_opts.visibility == "auto" and not user_opts.showonselect and not state.keeponpause_active then
        -- clear pending thumbnail
        if thumbfast.width ~= 0 and thumbfast.height ~= 0 then
            mp.commandv("script-message-to", "thumbfast", "clear")
        end
        osc_visible(false)
        wc_visible(false)
    end
end)
mp.observe_property("display-fps", "number", set_tick_delay)
observe_cached("demuxer-cache-state", request_tick)
mp.observe_property("vo-configured", "bool", request_tick)
mp.observe_property("playback-time", "number", request_tick)
observe_cached("osd-dimensions", request_init_resize)
observe_cached("osd-scale-by-window", request_init_resize)
mp.observe_property("touch-pos", "native", handle_touch)
observe_cached("volume", request_tick)
observe_cached("mute", request_tick)
observe_cached("eof-reached", request_tick)
observe_cached("ontop", request_init)
observe_cached("speed", request_tick)
observe_cached("chapter", request_tick)
-- ensure compatibility with auto loop scripts
mp.observe_property("loop-file", "bool", function(_, val)
    state.file_loop = (val ~= false)
end)
mp.observe_property("sub-pos", "native", function(_, value)
    if value == nil then return end
    if state.osc_adjusted_subpos == nil or value ~= state.osc_adjusted_subpos then
        state.user_subpos = value
    end
end)

-- mouse show/hide bindings
mp.set_key_bindings({
    {"mouse_move",              function() process_event("mouse_move", nil) end},
    {"mouse_leave",             mouse_leave},
}, "showhide", "force")
mp.set_key_bindings({
    {"mouse_move",              function() process_event("mouse_move", nil) end},
    {"mouse_leave",             mouse_leave},
}, "showhide_wc", "force")
do_enable_keybindings()

--mouse input bindings
mp.set_key_bindings({
    {"mbtn_left",           function() process_event("mbtn_left", "up") end,
                            function() process_event("mbtn_left", "down")  end},
    {"shift+mbtn_left",     function() process_event("shift+mbtn_left", "up") end,
                            function() process_event("shift+mbtn_left", "down")  end},
    {"mbtn_right",          function() process_event("mbtn_right", "up") end,
                            function() process_event("mbtn_right", "down")  end},
    {"shift+mbtn_right",    function() process_event("shift+mbtn_right", "up") end,
                            function() process_event("shift+mbtn_right", "down")  end},
    {"mbtn_left_dbl",       "ignore"},
    {"shift+mbtn_left_dbl", "ignore"},
    {"mbtn_right_dbl",      "ignore"},
}, "input", "force")
mp.enable_key_bindings("input")

mp.set_key_bindings({
    {"wheel_up",   function() process_event("wheel_up", "press") end},
    {"wheel_down", function() process_event("wheel_down", "press") end},
}, "input_wheel", "force")
mp.enable_key_bindings("input_wheel")

mp.set_key_bindings({
    {"mbtn_mid", function() process_event("shift+mbtn_left", "up") end,
                 function() process_event("shift+mbtn_left", "down")  end},
}, "input_mid", "force")
mp.enable_key_bindings("input_mid")

mp.set_key_bindings({
    {"mbtn_left",           function() process_event("mbtn_left", "up") end,
                            function() process_event("mbtn_left", "down")  end},
}, "window-controls", "force")
mp.enable_key_bindings("window-controls")

mp.set_key_bindings({
    {"mbtn_left",           function() process_event("mbtn_left", "up") end,
                            function() process_event("mbtn_left", "down")  end},
}, "window-controls-ontop", "force")
set_virt_mouse_area(0, 0, 0, 0, "window-controls-ontop")

mp.observe_property("pause", "bool", function(_, enabled)
    state.pause = (enabled == true)
    request_tick()
    if user_opts.showonpause and user_opts.visibility ~= "never" then
        state.enabled = enabled
        if enabled then
            if user_opts.keeponpause == "both" then
                -- save mode and set visibility to "always" temporarily
                if not state.keeponpause_restore and user_opts.visibility ~= "always" then
                    state.keeponpause_restore = user_opts.visibility
                end
                visibility_mode("always", true)
            elseif user_opts.keeponpause == "bottombar" then
                state.keeponpause_active = true
                show_osc()
            else
                show_osc()
            end
        else
            -- clear keeponpause bottombar active state
            state.keeponpause_active = false
            -- restore mode if it was changed by keeponpause=both
            if state.keeponpause_restore then
                visibility_mode(state.keeponpause_restore, true)
                state.keeponpause_restore = nil
            else
                -- respect "always" mode on unpause
                visibility_mode(user_opts.visibility, true)
            end
            -- reset timers so both bars get a fresh hidetimeout on unpause
            local now = mp.get_time()
            if state.osc_visible then state.showtime = now end
            if state.wc_visible then state.wc_showtime = now end
        end
    end
end)

mp.register_script_message("osc-visibility", visibility_mode)
mp.register_script_message("osc-show", show_osc)
mp.register_script_message("osc-hide", function()
    if user_opts.visibility == "auto" then
        hide_osc()
        hide_wc()
    end
end)
mp.add_key_binding(nil, "visibility", function() visibility_mode("cycle") end)
mp.add_key_binding(nil, "progress-toggle", function()
    user_opts.persistent_progress = not user_opts.persistent_progress
    state.persistent_progress_toggle = user_opts.persistent_progress
    request_init()
end)
mp.register_script_message("osc-idlescreen", idlescreen_visibility)
mp.register_script_message("thumbfast-info", function(json)
    local data = utils.parse_json(json)
    if type(data) ~= "table" or not data.width or not data.height then
        msg.error("thumbfast-info: received json didn't produce a table with thumbnail information")
    else
        for k in pairs(thumbfast) do thumbfast[k] = nil end
        for k, v in pairs(data) do thumbfast[k] = v end
    end
end)

-- read options from config and command-line
opt.read_options(user_opts, "modernz", function(changed)
    if changed.language then load_locale_file() end
    validate_user_opts()
    if changed.language then set_osc_locale() end
    set_icon_theme()
    set_osc_styles()
    set_time_styles(changed.timecurrent, changed.timems)
    if changed.tick_delay or changed.tick_delay_follow_display_fps then
        set_tick_delay("display_fps", mp.get_property_number("display_fps"))
    end
    request_tick()
    if changed.visibility then
        visibility_mode(user_opts.visibility, true)
    end
    request_init()
end)

load_locale_file()
validate_user_opts()
set_osc_locale()
set_icon_theme()
set_osc_styles()
set_time_styles(true, true)
set_tick_delay()
visibility_mode(user_opts.visibility, true)

set_virt_mouse_area(0, 0, 0, 0, "input")
set_virt_mouse_area(0, 0, 0, 0, "input_wheel")
set_virt_mouse_area(0, 0, 0, 0, "input_mid")
set_virt_mouse_area(0, 0, 0, 0, "window-controls")
set_virt_mouse_area(0, 0, 0, 0, "window-controls-title")
