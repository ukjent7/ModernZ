-- modernz :: modules/events.lua
-- Event dispatch, bar show/hide, tick main loop.

local assdraw = require "mp.assdraw"
local msg = require "mp.msg"

local core = require("modules.core")
local state = core.state
local osc_param = core.osc_param
local persistent_progress_enabled = core.persistent_progress_enabled

local user_opts = require("modules.options")

local _utils = require("modules.utils")
local kill_animation = _utils.kill_animation
local set_osd = _utils.set_osd
local get_touchtimeout = _utils.get_touchtimeout
local render_wipe = _utils.render_wipe
local clear_thumbfast = _utils.clear_thumbfast
local window_controls_enabled = _utils.window_controls_enabled
local _geometry_utils = require("modules.geometry_utils")
local get_virt_mouse_pos = _geometry_utils.get_virt_mouse_pos
local set_virt_mouse_area = _geometry_utils.set_virt_mouse_area
local scale_value = _geometry_utils.scale_value
local mouse_hit = _geometry_utils.mouse_hit
local mouse_in_area = _geometry_utils.mouse_in_area
local _margin_utils = require("modules.margin_utils")
local get_hidetimeout = _margin_utils.get_hidetimeout
local reset_margins = _margin_utils.reset_margins
local update_margins = _margin_utils.update_margins
local request_tick = core.request_tick
local request_init = core.request_init
local request_init_resize = core.request_init_resize
local set_tick = core.set_tick
local _rendering = require("modules.rendering")
local render_elements = _rendering.render_elements
local render_persistent_progress = _rendering.render_persistent_progress
local _osc_init = require("modules.osc_init")
local osc_init = _osc_init.osc_init
local _locale = require("modules.locale")
local locale = _locale.get_locale()
local _elements = require("modules.elements")
local get_elements = _elements.get_elements
local _constants = require("modules.constants")
local is_december = _constants.is_december
local logo_lines = _constants.logo_lines
local santa_hat_lines = _constants.santa_hat_lines

-- Reference stays valid: elements is rebuilt in place by prepare_elements().
local elements = get_elements()

local tick

local function show_bar(label, showtime_key, visible_key, anitype_key, set_visible)
    -- show when disabled can happen (e.g. mouse_move) due to async/delayed unbinding
    if not state.enabled then return end
    msg.trace("show_" .. label)
    state[showtime_key] = mp.get_time()
    if user_opts.fadeduration <= 0 then
        set_visible(true)
    elseif user_opts.fadein then
        if not state[visible_key] then
            state[anitype_key] = "in"
            request_tick()
        end
    else
        set_visible(true)
        state[anitype_key] = nil
    end
end

local function hide_bar(label, visible_key, anitype_key, set_visible)
    msg.trace("hide_" .. label)
    if not state.enabled then
        -- typically hide happens at render() from tick(), but now tick() is
        -- no-op and won't render again to remove the osc, so do that manually.
        state[visible_key] = false
        render_wipe(state.osd)
    elseif user_opts.fadeduration > 0 then
        if state[visible_key] then
            state[anitype_key] = "out"
            request_tick()
        end
    else
        set_visible(false)
    end
end

local function update_tracklist(_, track_list)
    state.audio_track_count = 0
    state.sub_track_count = 0

    for _, track in pairs(track_list) do
        if track.type == "audio" then
            state.audio_track_count = state.audio_track_count + 1
        elseif track.type == "sub" then
            state.sub_track_count = state.sub_track_count + 1
        end
    end

    request_init()
end


local function set_bar_visible(visible_key, visible)
    if state[visible_key] ~= visible then
        state[visible_key] = visible
        update_margins()
    end
    request_tick()
end

local function osc_visible(visible)
    set_bar_visible("osc_visible", visible)
end

local function wc_visible(visible)
    set_bar_visible("wc_visible", visible)
end


local function show_wc()
    show_bar("wc", "wc_showtime", "wc_visible", "wc_anitype", wc_visible)
end

local function hide_wc()
    hide_bar("wc", "wc_visible", "wc_anitype", wc_visible)
end

local function show_osc()
    if state.idle_active then return end
    show_bar("osc", "showtime", "osc_visible", "anitype", osc_visible)
end

local function hide_osc()
    -- close speed menu if open
    state.speed_menu_open = false
    -- clear any pending thumbnail before hiding
    clear_thumbfast()
    -- clear input area immediately so clicks pass through while the bar is
    -- hidden, rather than waiting for the next render tick to do it
    set_virt_mouse_area(0, 0, 0, 0, "input")
    -- reset margins before hide_bar wipes the overlay
    if not state.enabled then
        reset_margins()
    end
    hide_bar("osc", "osc_visible", "anitype", osc_visible)
end

local function mouse_leave()
    if get_hidetimeout() >= 0 and get_touchtimeout() <= 0 then
        if user_opts.deadzone_hide == "timeout" then
            local now = mp.get_time()
            if state.osc_visible and not state.keeponpause_active and not state.speed_menu_open then
                state.showtime = now
            end
            if state.wc_visible then
                state.wc_showtime = now
            end
            request_tick()
        else
            if not state.keeponpause_active and not state.speed_menu_open then hide_osc() end
            hide_wc()
        end
    end
    -- reset mouse position
    state.last_mouseX, state.last_mouseY = nil, nil
    state.mouse_in_window = false
end

local function handle_touch(_, touchpoints)
    --remember last touch points
    if touchpoints then
        state.touchpoints = touchpoints
        if #touchpoints > 0 then
            --remember last time of invocation (touch event)
            state.touchtime = mp.get_time()
            state.last_touchX = touchpoints[1].x
            state.last_touchY = touchpoints[1].y
        end
    end
end

--
-- Event handling
--
local function reset_timeout()
    local now = mp.get_time()
    if window_controls_enabled() and user_opts.windowcontrols_independent then
        -- only reset the timer for the bar the event belongs to
        if mouse_in_area({"window-controls", "window-controls-title", "window-controls-ontop"}) then
            state.wc_showtime = now
        else
            state.showtime = now
        end
    else
        state.showtime = now
        state.wc_showtime = now
    end
end

local function element_has_action(element, action)
    return element and element.eventresponder and element.eventresponder[action]
end

-- dynamically sets the "input" mouse area to only the hovered element
local click_keys = {
    "mbtn_left_up", "mbtn_left_down", "mbtn_left_press",
    "mbtn_right_up", "mbtn_right_down", "mbtn_right_press",
}
local function has_click_action(e)
    if not e.eventresponder then return false end
    for _, k in ipairs(click_keys) do
        if e.eventresponder[k] then return true end
    end
    return false
end

local function has_wheel_action(e)
    if not e.eventresponder then return false end
    return e.eventresponder["wheel_up_press"] ~= nil or e.eventresponder["wheel_down_press"] ~= nil
end

local function has_mid_action(e)
    if not e.eventresponder then return false end
    return e.eventresponder["shift+mbtn_left_down"] ~= nil
end

-- Set the three input mouse areas (click / wheel / mid) in one call. A nil
-- area collapses to a zero-sized region (so that section passes clicks through).
local function set_input_areas(click, wheel, mid)
    local function set(name, area)
        set_virt_mouse_area(area and area.x1 or 0, area and area.y1 or 0,
                            area and area.x2 or 0, area and area.y2 or 0, name)
    end
    set("input", click)
    set("input_wheel", wheel)
    set("input_mid", mid)
end

local function refresh_input_area()
    if not state.osc_visible then
        set_input_areas()
        return
    end

    -- when speed menu is open, capture full screen for backdrop clicks
    if state.speed_menu_open then
        set_input_areas({x1 = 0, y1 = 0, x2 = osc_param.playresx, y2 = osc_param.playresy})
        return
    end

    -- during an active drag, keep the input area locked to the held element
    if state.active_element and elements[state.active_element] then
        local hb = elements[state.active_element].hitbox
        set_input_areas(hb, hb, hb)
        return
    end

    -- bail early if the cursor isn't inside the bottom bar zone at all
    if not mouse_in_area("input") then
        set_input_areas()
        return
    end

    -- find the topmost element under the cursor for each input type in one pass;
    -- layer order matches process_event's dispatch priority
    local hovered_click, hovered_wheel, hovered_mid = nil, nil, nil
    for n = 1, #elements do
        local e = elements[n]
        if e.hitbox and mouse_hit(e) then
            if has_click_action(e) then hovered_click = e end
            if has_wheel_action(e) then hovered_wheel = e end
            if has_mid_action(e)   then hovered_mid   = e end
        end
    end

    set_input_areas(hovered_click and hovered_click.hitbox or nil,
                    hovered_wheel and hovered_wheel.hitbox or nil,
                    hovered_mid and hovered_mid.hitbox or nil)
end

-- Cache event action strings (source/event combinations are a small fixed
-- set, so the concatenation is computed once per unique pair).
local action_cache = {}
local function get_action(source, what)
    local key = source .. "|" .. tostring(what)
    local a = action_cache[key]
    if a == nil then
        a = string.format("%s%s", source, what and ("_" .. what) or "")
        action_cache[key] = a
    end
    return a
end

local function process_event(source, what)
    local action = get_action(source, what)

    if what == "down" or what == "press" then
        reset_timeout() -- clicking resets the hideosc timer

        for n = 1, #elements do
            if mouse_hit(elements[n]) and
                elements[n].eventresponder and
                (elements[n].eventresponder[source .. "_up"] or
                    elements[n].eventresponder[action]) then

                if what == "down" then
                    state.active_element = n
                    state.active_event_source = source
                end
                -- fire the down or press event if the element has one
                if element_has_action(elements[n], action) then
                    elements[n].eventresponder[action](elements[n])
                end
            end
        end
    elseif what == "up" then
        if elements[state.active_element] then
            local n = state.active_element

            if n == 0 then
                --click on background (does not work)
            elseif element_has_action(elements[n], action) and
                mouse_hit(elements[n]) then

                elements[n].eventresponder[action](elements[n])
            end

            --reset active element
            if element_has_action(elements[n], "reset") then
                elements[n].eventresponder["reset"](elements[n])
            end
        end
        state.active_element = nil
        state.mouse_down_counter = 0
    elseif source == "mouse_move" then
        state.mouse_in_window = true

        local mouseX, mouseY = get_virt_mouse_pos()
        if user_opts.minmousemove == 0 or
            ((state.last_mouseX ~= nil and state.last_mouseY ~= nil) and
                (math.abs(mouseX - state.last_mouseX) >= user_opts.minmousemove or
                 math.abs(mouseY - state.last_mouseY) >= user_opts.minmousemove)) then
            if window_controls_enabled() and user_opts.windowcontrols_independent then
                if mouse_in_area("showhide_wc") then
                    show_wc()
                elseif user_opts.visibility ~= "always" and user_opts.deadzone_hide ~= "timeout" then
                    hide_wc()
                end
                if mouse_in_area("showhide") or state.speed_menu_open then
                    show_osc()
                elseif user_opts.visibility ~= "always" and not state.keeponpause_active and user_opts.deadzone_hide ~= "timeout" then
                    hide_osc()
                end
            else
                show_osc()
                if window_controls_enabled() then show_wc() end
            end
        end
        state.last_mouseX, state.last_mouseY = mouseX, mouseY

        local n = state.active_element
        if element_has_action(elements[n], action) then
            elements[n].eventresponder[action](elements[n])
        end

        -- update input area to follow the cursor so only the element
        -- currently under it captures clicks; empty space passes through
        refresh_input_area()
    end

    -- ensure rendering after any (mouse) event - icons could change etc
    request_tick()
end

local function do_enable_keybindings()
    if state.enabled then
        if not state.showhide_enabled then
            mp.enable_key_bindings("showhide", "allow-vo-dragging+allow-hide-cursor")
            mp.enable_key_bindings("showhide_wc", "allow-vo-dragging+allow-hide-cursor")
        end
        state.showhide_enabled = true
    end
end

local function enable_osc(enable)
    state.enabled = enable
    if enable then
        do_enable_keybindings()
    else
        hide_osc() -- acts immediately when state.enabled == false
        hide_wc()
        if state.showhide_enabled then
            mp.disable_key_bindings("showhide")
            mp.disable_key_bindings("showhide_wc")
        end
        state.showhide_enabled = false
    end
end

local function render()
    msg.trace("rendering")
    local current_screen_sizeX = state.osd_dimensions.w
    local current_screen_sizeY = state.osd_dimensions.h
    local mouseX, mouseY = get_virt_mouse_pos()
    local now = mp.get_time()

    -- check if display changed, if so request reinit
    if state.screen_sizeX ~= current_screen_sizeX or state.screen_sizeY ~= current_screen_sizeY then
        request_init_resize()

        state.screen_sizeX = current_screen_sizeX
        state.screen_sizeY = current_screen_sizeY
    end

    -- init management
    if state.active_element then
        -- mouse is held down on some element - keep ticking and ignore initReq
        -- till it's released, or else the mouse-up (click) will misbehave or
        -- get ignored. that's because osc_init() recreates the osc elements,
        -- but mouse handling depends on the elements staying unmodified
        -- between mouse-down and mouse-up (using the index active_element).
        request_tick()
    elseif state.initREQ then
        osc_init()
        state.initREQ = false

        -- store initial mouse position
        if (state.last_mouseX == nil or state.last_mouseY == nil) and not (mouseX == nil or mouseY == nil or mouseX == -1 or mouseY == -1) then
            state.last_mouseX, state.last_mouseY = mouseX, mouseY
        end
    end

    -- fade animation
    local function run_fade(anitype_key, anistart_key, animation_key, set_visible)
        local anitype = state[anitype_key]
        if anitype == nil then
            kill_animation(anitype_key, anistart_key, animation_key)
            return
        end
        if state[anistart_key] == nil then state[anistart_key] = now end
        local fadelen = user_opts.fadeduration / 1000
        if now < state[anistart_key] + fadelen then
            if anitype == "in" then
                set_visible(true)
                state[animation_key] = scale_value(state[anistart_key],
                    state[anistart_key] + fadelen, 255, 0, now)
            elseif anitype == "out" then
                state[animation_key] = scale_value(state[anistart_key],
                    state[anistart_key] + fadelen, 0, 255, now)
            end
        else
            if anitype == "out" then set_visible(false) end
            kill_animation(anitype_key, anistart_key, animation_key)
        end
    end
    run_fade("anitype",    "anistart",    "animation",    osc_visible)
    run_fade("wc_anitype", "wc_anistart", "wc_animation", wc_visible)

    --mouse show/hide area
    -- areas can be empty before the first osc_init() has laid out the bars;
    -- guard the table so a tick never trips over pairs(nil)
    for _, cords in pairs(osc_param.areas["showhide"] or {}) do
        set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "showhide")
    end
    if osc_param.areas["showhide_wc"] then
        for _, cords in pairs(osc_param.areas["showhide_wc"]) do
            set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "showhide_wc")
        end
    else
        set_virt_mouse_area(0, 0, 0, 0, "showhide_wc")
    end
    do_enable_keybindings()

    --mouse input area
    local function update_input_area(area_name, visible, enabled_key, enable_fn)
        local areas = osc_param.areas[area_name]
        if not areas then return end
        for _, cords in ipairs(areas) do
            if visible then
                set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, area_name)
            end
            if visible ~= state[enabled_key] then
                if visible then enable_fn() else mp.disable_key_bindings(area_name) end
                state[enabled_key] = visible
            end
        end
    end

    -- sync input area to cursor position
    if state.osc_visible ~= state.input_enabled then
        if state.osc_visible then
            mp.enable_key_bindings("input")
        else
            mp.disable_key_bindings("input")
        end
        state.input_enabled = state.osc_visible
    end
    refresh_input_area()

    update_input_area("window-controls", state.wc_visible, "windowcontrols_buttons", function() mp.enable_key_bindings("window-controls") end)
    -- The "window-controls-title" binding section is intentionally never
    -- defined with set_key_bindings (see main.lua). It exists only so the
    -- title area claims the mouse input region with "allow-vo-dragging",
    -- letting clicks fall through to the window manager (drag-to-move) instead
    -- of triggering mpv's default bindings. Do not add bindings to it.
    update_input_area("window-controls-title", state.wc_visible, "windowcontrols_title", function() mp.enable_key_bindings("window-controls-title", "allow-vo-dragging") end)
    update_input_area("window-controls-ontop", state.wc_visible, "windowcontrols_ontop", function() mp.enable_key_bindings("window-controls-ontop") end)

    -- autohide
    local function run_autohide(showtime_key, hide_fn, input_areas)
        local hide_timeout = get_hidetimeout()
        if state[showtime_key] == nil or hide_timeout < 0 then return end
        local timeout = state[showtime_key] + (hide_timeout / 1000) - now
        if timeout <= 0 and get_touchtimeout() <= 0 then
            -- a hold in the bottom bar should not prevent the top bar from hiding, and vice versa.
            local element_blocks_hide = state.active_element ~= nil and mouse_in_area(input_areas)
            if not element_blocks_hide and (not user_opts.keep_with_cursor or not mouse_in_area(input_areas)) then
                hide_fn()
            end
        else
            if not state.hide_timer then
                state.hide_timer = mp.add_timeout(0, tick)
            end
            if timeout < state.hide_timer.timeout then
                state.hide_timer.timeout = timeout
                state.hide_timer:kill()
                state.hide_timer:resume()
            end
        end
    end

    local osc_areas = {"input"}
    local wc_areas  = {"window-controls", "window-controls-title", "window-controls-ontop"}
    if not user_opts.windowcontrols_independent then
        osc_areas = {"input", "window-controls", "window-controls-title", "window-controls-ontop"}
        wc_areas = osc_areas
    end

    if state.hide_timer then state.hide_timer.timeout = math.huge end
    if not state.keeponpause_active and not state.speed_menu_open then
        run_autohide("showtime", hide_osc, osc_areas)
    end
    run_autohide("wc_showtime", hide_wc, wc_areas)

    -- actual rendering
    local ass = assdraw.ass_new()

    if state.osc_visible or state.wc_visible then
        render_elements(ass, state.osc_visible, state.wc_visible)
    end

    if persistent_progress_enabled() then
        render_persistent_progress(ass)
    end

    -- submit
    set_osd(state.osd, osc_param.playresy * osc_param.display_aspect, osc_param.playresy, ass.text, 1000)
end

-- called by mpv on every frame
tick = function()
    if state.marginsREQ == true then
        update_margins()
        state.marginsREQ = false
    end

    if not state.enabled then return end

    if state.idle_active then
        msg.trace("idle message")
        if user_opts.idlescreen then
            local display_aspect = state.osd_dimensions.aspect
            if display_aspect == 0 then return end
            local display_h = 360
            local display_w = display_h * display_aspect
            -- logo is rendered at 2^(6-1) = 32 times resolution with size 1800x1800
            local icon_x, icon_y = (display_w - 1800 / 32) / 2, 140
            local line_prefix = ("{\\rDefault\\an7\\1a&H00&\\bord0\\shad0\\pos(%f,%f)}"):format(icon_x, icon_y)

            local ass = assdraw.ass_new()
            -- mpv logo
            for _, line in ipairs(logo_lines) do
                ass:new_event()
                ass:append(line_prefix .. line)
            end

            -- Santa hat
            if is_december and not user_opts.greenandgrumpy then
                for _, line in ipairs(santa_hat_lines) do
                    ass:new_event()
                    ass:append(line_prefix .. line)
                end
            end

            ass:new_event()
            ass:pos(display_w / 2, icon_y + 65)
            ass:an(8)
            ass:append("{\\fs24\\1c&HFFFFFF&}" .. locale.idle)
            set_osd(state.logo_osd, display_w, display_h, ass.text, -1000)
        end

        if state.osc_visible then
            osc_visible(false)
        end

        if window_controls_enabled() then
            render()
        else
            render_wipe(state.osd)
            if state.showhide_enabled then
                mp.disable_key_bindings("showhide")
                mp.disable_key_bindings("showhide_wc")
                state.showhide_enabled = false
            end
        end
    elseif (state.fullscreen and user_opts.showfullscreen) or (not state.fullscreen and user_opts.showwindowed) then
        render_wipe(state.logo_osd)
        render()
    else
        -- Flush OSD
        render_wipe(state.osd)
        render_wipe(state.logo_osd)
    end

    state.tick_last_time = mp.get_time()

    local function tick_animation(anitype_key, anistart_key, animation_key, allow_idle)
        if state[anitype_key] ~= nil then
            if (allow_idle or not state.idle_active) and
               (not state[anistart_key] or
                mp.get_time() < 1 + state[anistart_key] + user_opts.fadeduration / 1000)
            then
                request_tick()
            else
                kill_animation(anitype_key, anistart_key, animation_key)
            end
        end
    end
    tick_animation("anitype",    "anistart",    "animation")
    tick_animation("wc_anitype", "wc_anistart", "wc_animation", window_controls_enabled())
end

local function always_on(val)
    if state.enabled then
        if val then
            show_osc()
            show_wc()
        else
            hide_osc()
            hide_wc()
        end
    end
end

-- Disable all input-area key bindings and reset their enabled-state flags.
-- Called on visibility mode changes; the areas are recalculated on the next
-- render cycle, except in 'never' mode where they stay disabled.
local function reset_input_state()
    mp.disable_key_bindings("input")
    mp.disable_key_bindings("window-controls")
    mp.disable_key_bindings("window-controls-title")
    mp.disable_key_bindings("window-controls-ontop")
    state.input_enabled = false
    state.windowcontrols_buttons = false
    state.windowcontrols_title = false
    state.windowcontrols_ontop = false
end

-- mode can be auto/always/never/cycle
-- the modes only affect internal variables and not stored on its own.
local function visibility_mode(mode, no_osd)
    if mode == "cycle" then
        for i, allowed_mode in ipairs(state.visibility_modes) do
            if i == #state.visibility_modes then
                mode = state.visibility_modes[1]
                break
            elseif user_opts.visibility == allowed_mode then
                mode = state.visibility_modes[i + 1]
                break
            end
        end
    end

    if mode == "auto" then
        always_on(false)
        enable_osc(true)
    elseif mode == "always" then
        enable_osc(true)
        always_on(true)
    elseif mode == "never" then
        enable_osc(false)
    else
        msg.warn("Ignoring unknown visibility mode '" .. mode .. "'")
        return
    end

    user_opts.visibility = mode
    mp.set_property_native("user-data/osc/visibility", mode)

    if not no_osd and tonumber(mp.get_property("osd-level")) >= 1 then
        mp.osd_message("OSC visibility: " .. mode)
    end

    -- Reset the input state on a mode change (recalculated next render cycle).
    reset_input_state()

    update_margins()
    request_tick()
end

local function idlescreen_visibility(mode, no_osd)
    if mode == "cycle" then
        mode = user_opts.idlescreen and "no" or "yes"
    end

    user_opts.idlescreen = (mode == "yes")

    mp.set_property_native("user-data/osc/idlescreen", user_opts.idlescreen)

    if not no_osd and tonumber(mp.get_property("osd-level")) >= 1 then
        mp.osd_message("OSC logo visibility: " .. tostring(mode))
    end

    request_tick()
end

set_tick(tick)

return {
    update_tracklist = update_tracklist,
    osc_visible = osc_visible,
    wc_visible = wc_visible,
    show_wc = show_wc,
    hide_wc = hide_wc,
    show_osc = show_osc,
    hide_osc = hide_osc,
    mouse_leave = mouse_leave,
    handle_touch = handle_touch,
    reset_timeout = reset_timeout,
    process_event = process_event,
    do_enable_keybindings = do_enable_keybindings,
    visibility_mode = visibility_mode,
    idlescreen_visibility = idlescreen_visibility,
}
