-- modernz :: modules/layouts.lua
-- Layout definitions (default/compact/mini/seekbar/modern-image), window
-- controls, and the speed menu.

local core = require("modules.core")
local state = core.state
local osc_param = core.osc_param
local persistent_progress_enabled = core.persistent_progress_enabled

local user_opts = require("modules.options")

local _utils = require("modules.utils")
local get_time_codes_width = _utils.get_time_codes_width
local window_controls_enabled = _utils.window_controls_enabled
local _geometry_utils = require("modules.geometry_utils")
local get_align = _geometry_utils.get_align
local get_hitbox_coords = _geometry_utils.get_hitbox_coords
local add_area = _geometry_utils.add_area
local _elements = require("modules.elements")
local new_element = _elements.new_element
local add_layout = _elements.add_layout
local get_elements = _elements.get_elements
local request_init = core.request_init
local _constants = require("modules.constants")
local window_control_box_width = _constants.window_control_box_width
local DEFAULT_SPEED_PRESETS = _constants.DEFAULT_SPEED_PRESETS
local _string_utils = require("modules.string_utils")
local contains = _string_utils.contains
local _styles = require("modules.styles")
local osc_color_convert = _styles.osc_color_convert
local osc_styles = _styles.get_osc_styles()
local seekbar_height_style = _styles.get_seekbar_height_style()
local hover_effects = _styles.get_hover_effects()

-- Private layouts table, owned by this module
local layouts = {}

-- Reference stays valid: elements is rebuilt in place by prepare_elements().
local elements = get_elements()

-- Layout build state. Only one layout runs per osc_init, so these module-level
-- slots (written by the layout and its shared helpers) are safe to reuse.
local lo
local refY
local outeroffset

-- Initializes the canvas geometry, bottom margin, and input/showhide areas for
-- a layout. Returns posX, posY, refX, refY and sets the module-level refY.
local function begin_osc_layout(osc_h)
    local osc_geo = { w = osc_param.playresx, h = osc_h }
    osc_param.video_margins.b = osc_geo.h / osc_param.playresy

    -- origin of the controllers, left/bottom corner
    local posX, posY = 0, osc_param.playresy
    refY = posY

    osc_param.areas = {} -- delete areas

    -- area for active mouse input
    add_area("input", get_hitbox_coords(posX, posY, 1, osc_geo.w, osc_geo.h))

    -- area for show/hide
    local osc_top = posY - osc_geo.h
    add_area("showhide", 0, get_align(-1 + (2 * user_opts.deadzonesize), osc_top, 0, 0), osc_param.playresx, osc_param.playresy)

    return posX, posY, osc_geo.w / 2, posY
end

-- Returns left/right side-button layout helpers sharing a position table.
-- cfg: {style, step, row_y, adjust_left, adjust_right, h, pos}. The helpers
-- step pos.left/pos.right outward, so call order matters. Left supports an
-- extra visibility condition (vis_extra) and a per-call step override.
local function make_side_buttons(cfg)
    local function left(name, min_w, w, step, style, vis_extra)
        local vis = (osc_param.playresx >= (cfg.adjust_left and min_w - outeroffset or min_w))
            and (vis_extra == nil or vis_extra)
        elements[name].visible = vis
        if vis then
            lo = add_layout(name)
            lo.geometry = {x = cfg.pos.left, y = refY - cfg.row_y, an = 5, w = w or 24, h = cfg.h or 24}
            lo.style = style or cfg.style
            cfg.pos.left = cfg.pos.left + (step or cfg.step)
        end
    end
    local function right(name, min_w, vis_extra, style, w)
        local vis = (osc_param.playresx >= (cfg.adjust_right and min_w - outeroffset or min_w))
            and (vis_extra == nil or vis_extra)
        elements[name].visible = vis
        if vis then
            lo = add_layout(name)
            lo.geometry = {x = cfg.pos.right, y = refY - cfg.row_y, an = 5, w = w or 24, h = cfg.h or 24}
            lo.style = style or cfg.style
            cfg.pos.right = cfg.pos.right - cfg.step
        end
    end
    return left, right
end

-- Side-button visibility thresholds for the default layout (playresx px).
-- Compact/mini use their own smaller thresholds, so these names only make the
-- default layout's intent explicit.
local THRESHOLD = {
    playlist = 550, audio = 650, subs = 750, volume = 850,
    fullscreen = 550, info = 650, ontop = 750, screenshot = 850,
    file_loop = 950, shuffle = 1050, speed = 1150, download = 1150, cache = 1250,
    prevnext = 500, chapter = 400,
}

-- Builds the volume bar (bg + bar + vol_ctrl hover box) at the given row and
-- advances pos.left past the bar. row_y is the row offset from the bottom edge.
local function setup_volumebar(pos, row_y, vol_vis, hover_pad)
    local ne = new_element("volumebarbg", "box")
    ne.visible = vol_vis
    elements["volumebar"].visible = vol_vis
    if vol_vis then
        lo = add_layout("volumebarbg")
        lo.geometry = {x = pos.left, y = refY - row_y, an = 4, w = 55, h = 4}
        lo.layer = 15
        lo.alpha[1] = 128
        lo.style = user_opts.volumebar_match_seek_color and osc_styles.seekbar_bg or osc_styles.volumebar_bg
        lo.box.radius = user_opts.slider_rounded_corners and 2 or 0

        lo = add_layout("volumebar")
        lo.geometry = {x = pos.left, y = refY - row_y, an = 4, w = 55, h = 10}
        lo.style = user_opts.volumebar_match_seek_color and osc_styles.seekbar_fg or osc_styles.volumebar_fg
        lo.slider.handle_color = user_opts.volumebar_match_seek_color and user_opts.seekbarfg_color or user_opts.side_buttons_color
        lo.slider.gap = 3
        lo.slider.radius = user_opts.slider_rounded_corners and 2 or 0
        lo.slider.tooltip_an = 2
        pos.left = pos.left + 75
        -- vol_ctrl center = bar_start - 20; bar_start = pos.left - 75; left edge = center - hover_pad
        local vc_left = pos.left - 107
        local osc_mid = refY - row_y
        elements["vol_ctrl"].hover_box = {x1 = vc_left, y1 = osc_mid - hover_pad, x2 = vc_left + 87, y2 = osc_mid + hover_pad}
    else
        elements["vol_ctrl"].hover_box = nil
    end
end

-- Shared title/chapter_title layout boilerplate. Each layout supplies the
-- geometry numbers that differ (widths and horizontal origins); everything
-- else (clipping, layers, alpha, max-width bookkeeping) is identical.
local function setup_title_and_chapter(title_y, title_w, title_x, chapter_title_y, chapter_title_w, chapter_title_x)
    state.title_max_w = title_w
    if title_w < 0 then title_w = 0 end
    elements["title"].visible = user_opts.show_title
    local geo = {x = title_x, y = refY - title_y, an = 1, w = title_w, h = user_opts.title_font_size}
    lo = add_layout("title")
    lo.geometry = geo
    lo.layer = 48
    lo.alpha[3] = 0
    lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}", osc_styles.title, 0, 0, geo.x + geo.w, geo.y + geo.h)

    if user_opts.show_chapter_title then
        elements["chapter_title"].visible = user_opts.show_chapter_title and (state.chapter or -1) >= 0
        geo = {x = chapter_title_x, y = refY - chapter_title_y, an = 1, w = chapter_title_w, h = user_opts.chapter_title_font_size}
        lo = add_layout("chapter_title")
        lo.geometry = geo
        lo.layer = 48
        lo.alpha[3] = 0
        lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}", osc_styles.chapter_title, 0, 0, geo.x + geo.w, geo.y + geo.h)
        state.chapter_title_max_w = geo.w
    end
end

local function window_controls()
    local wc_geo = {
        x = 0,
        y = 50,
        an = 1,
        w = osc_param.playresx,
        h = 50,
    }

    local lo
    local ontop_active = user_opts.ontop_button and window_controls_enabled() and user_opts.ontop_in_topbar and state.ontop
    local controlbox_w = (user_opts.window_controls and window_control_box_width or 0)
    local controlbox_left = wc_geo.w - controlbox_w
    local titlebox_left = ontop_active and 50 or wc_geo.x
    local button_y = wc_geo.y - (wc_geo.h / 2)
    local first_geo  = {x = controlbox_left + 25,  y = button_y, an = 5, w = 50, h = wc_geo.h}
    local second_geo = {x = controlbox_left + 75, y = button_y, an = 5, w = 49, h = wc_geo.h}
    local third_geo  = {x = controlbox_left + 125, y = button_y, an = 5, w = 50, h = wc_geo.h}

    -- Window controls
    if user_opts.window_controls then
        local size_hover = hover_effects.size and
            string.format("\\fscx%s\\fscy%s", user_opts.button_hover_size, user_opts.button_hover_size) or ""
        local function wc_hoverstyle(color)
            return "{\\1c&H" .. osc_color_convert(color) .. "&" .. size_hover .. "}"
        end

        local function wc_button(name, geom, hover_color)
            lo = add_layout(name)
            lo.geometry = geom
            lo.style = osc_styles.window_control
            lo.group = "top"
            lo.button.hoverstyle = wc_hoverstyle(hover_color)
        end

        wc_button("close", third_geo, user_opts.windowcontrols_close_hover) -- Close: 🗙
        wc_button("maximize", second_geo, user_opts.windowcontrols_max_hover) -- Maximize: 🗖/🗗
        wc_button("minimize", first_geo, user_opts.windowcontrols_min_hover) -- Minimize: 🗕
    end

    -- ontop button in top bar when ontop is active
    if ontop_active then
        elements["ontop"].visible = osc_param.playresx >= controlbox_w + 35
        elements["ontop"].hover_radius = 0
        elements["ontop"].hover_pad = 0
        lo = add_layout("ontop")
        lo.geometry = {x = 25, y = button_y, an = 5, w = 50, h = wc_geo.h}
        lo.style = osc_styles.window_control
        lo.group = "top"
        lo.button.hoverstyle = osc_styles.element_hover
    end

    -- Window Title
    if user_opts.show_window_title then
        lo = add_layout("windowtitle")
        lo.geometry = {x = math.max(20, titlebox_left + 4), y = button_y + 14, an = 1, w = osc_param.playresx - 50, h = wc_geo.h}
        lo.group = "top"
        lo.alpha[3] = 0
        lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}", osc_styles.window_title, titlebox_left, wc_geo.y - wc_geo.h, controlbox_left, wc_geo.y + wc_geo.h)
        state.windowtitle_max_w = controlbox_left - math.max(20, titlebox_left + 4)
    end

    -- only add top areas and margin if one of the elements is enabled
    if (user_opts.show_window_title or user_opts.window_controls or ontop_active) then
        -- deadzone below window controls
        local sh_area_y1 = wc_geo.y + get_align(1 - (2 * user_opts.deadzonesize), osc_param.playresy - wc_geo.y, 0, 0)
        add_area("showhide_wc", wc_geo.x, 0, wc_geo.w, sh_area_y1)
        add_area("window-controls", get_hitbox_coords(controlbox_left, wc_geo.y, wc_geo.an, controlbox_w, wc_geo.h))
        if ontop_active then add_area("window-controls-ontop", 0, 0, 50, wc_geo.h) end
        add_area("window-controls-title", titlebox_left, 0, controlbox_left, wc_geo.h)
        -- top bar margins
        osc_param.video_margins.t = wc_geo.h / osc_param.playresy
    end
end

--
-- ModernZ Layouts
--

local function setup_bg_elements(posX, posY, osc_w, osc_h, osc_alpha3, wc_alpha3)
    new_element("osc_fade_bg", "box")
    local lo = add_layout("osc_fade_bg")
    lo.geometry = {x = posX, y = posY, an = 7, w = osc_w, h = osc_h}
    lo.style = osc_styles.osc_fade_bg
    lo.layer = 10
    lo.alpha[3] = osc_alpha3

    if window_controls_enabled() and (user_opts.show_window_title or user_opts.window_controls) then
        -- Top bar fade background. The negative height (-1) with an=7 is
        -- deliberate: the box's bottom edge sits at y=-100 (just above the
        -- playarea) and it extends upward off-screen, so the window-fade
        -- gradient only ever covers the strip above the visible bar. Do not
        -- "fix" the geometry to a positive height without re-testing.
        new_element("window_bar_alpha_bg", "box")
        lo = add_layout("window_bar_alpha_bg")
        lo.geometry = {x = posX, y = -100, an = 7, w = osc_w, h = -1}
        lo.style = osc_styles.window_fade_bg
        lo.layer = 10
        lo.group = "top"
        lo.alpha[3] = wc_alpha3
    end
end

-- Shared seekbar + persistent progress block for the default/compact/mini
-- layouts. seekbar_y is the vertical center of the seekbar (refY - offset);
-- the persistent progress line (if enabled) always sits on refY (screen bottom).
local function setup_seekbar(refX, refY, seekbar_y)
    local lo

    local seekbarbg = new_element("seekbarbg", "box")
    seekbarbg.visible = user_opts.nibbles_style ~= "gap"
    lo = add_layout("seekbarbg")
    local seekbar_bg_h = seekbar_height_style.height
    lo.geometry = {x = refX, y = seekbar_y, an = 5, w = osc_param.playresx - 30, h = seekbar_bg_h}
    lo.layer = 15
    lo.style = osc_styles.seekbar_bg
    lo.box.radius = user_opts.slider_rounded_corners and seekbar_height_style.radius or 0
    lo.alpha[1] = 128

    lo = add_layout("seekbar")
    local seekbar_h = 18
    lo.geometry = {x = refX, y = seekbar_y, an = 5, w = osc_param.playresx - 30, h = seekbar_h}
    lo.layer = 49
    lo.style = osc_styles.seekbar_fg
    lo.slider.handle_color = user_opts.seek_handle_color
    lo.slider.handle_border = user_opts.seek_handle_border_color
    lo.slider.gap = (seekbar_h - seekbar_bg_h) / 2.0
    lo.slider.radius = user_opts.slider_rounded_corners and seekbar_height_style.radius or 0
    lo.slider.tooltip_an = 2

    if persistent_progress_enabled() then
        lo = add_layout("persistent_seekbar")
        lo.geometry = {x = refX, y = refY, an = 5, w = osc_param.playresx, h = user_opts.persistent_progress_height}
        lo.style = osc_styles.seekbar_fg
        lo.slider.gap = (seekbar_h - seekbar_bg_h) / 2.0
        lo.slider.tooltip_an = 0
    end
end

-- parse speed presets from user_opts string into a table
local function get_speed_presets()
    local presets = {}
    for val in user_opts.speed_presets:gmatch("[^,]+") do
        local num = tonumber(val:match("^%s*(.-)%s*$"))
        if num and num > 0 then presets[#presets + 1] = num end
    end
    if #presets == 0 then
        for i, v in ipairs(DEFAULT_SPEED_PRESETS) do presets[i] = v end
    end
    return presets
end

-- YouTube-style speed menu: a small title, a big speed readout, a horizontal
-- slider flanked by -/+ buttons, and a row of preset pills. Shared by all layouts.
local function layout_speed_menu()
    local presets = get_speed_presets()
    local menu_open = elements["speed"] and elements["speed"].visible and state.speed_menu_open

    if not menu_open then
        elements["speed_menu_backdrop"].visible = false
        elements["speed_menu_bg"].visible = false
        elements["speed_menu_title"].visible = false
        elements["speed_menu_value"].visible = false
        elements["speed_slider_bg"].visible = false
        elements["speed_slider"].visible = false
        elements["speed_dec"].visible = false
        elements["speed_inc"].visible = false
        for i = 1, #presets do
            elements["speed_preset_" .. i].visible = false
        end
        return
    end

    local speed_x = elements["speed"].layout.geometry.x
    local speed_y = elements["speed"].layout.geometry.y
    local accent = user_opts.seekbarfg_color

    -- panel geometry
    local panel_w = math.min(340, osc_param.playresx - 16)
    local pad_x = 16
    local pad_top = 12
    local pad_bottom = 12
    local title_h = 16
    local value_h = 36
    local slider_row_h = 30
    local preset_row_h = 26
    local gap_tv = 2    -- title -> value
    local gap_vs = 6    -- value -> slider
    local gap_sp = 10   -- slider -> presets

    local panel_h = pad_top + title_h + gap_tv + value_h + gap_vs + slider_row_h + gap_sp + preset_row_h + pad_bottom

    -- keep the panel inside the screen
    local panel_x = speed_x - panel_w / 2
    panel_x = math.max(8, math.min(panel_x, osc_param.playresx - panel_w - 8))
    local panel_y = speed_y - 24 - panel_h
    if panel_y < 8 then panel_y = 8 end

    -- backdrop covers the whole screen, click outside to close
    elements["speed_menu_backdrop"].visible = true
    local lo = add_layout("speed_menu_backdrop")
    lo.geometry = {x = 0, y = 0, an = 7, w = osc_param.playresx, h = osc_param.playresy}
    lo.layer = 60
    lo.style = "{\\1c&H000000&\\alpha&HFF&}"

    -- panel background
    elements["speed_menu_bg"].visible = true
    lo = add_layout("speed_menu_bg")
    lo.geometry = {x = panel_x, y = panel_y, an = 7, w = panel_w, h = panel_h}
    lo.layer = 61
    lo.style = "{\\1c&H" .. osc_color_convert(user_opts.osc_color) .. "&\\bord1\\3c&H555555&}"
    lo.box.radius = 10
    lo.alpha[1] = 12

    -- vertical centers of each row (absolute coordinates)
    local title_cy  = panel_y + pad_top + title_h / 2
    local value_cy  = title_cy + title_h / 2 + gap_tv + value_h / 2
    local slider_cy = value_cy + value_h / 2 + gap_vs + slider_row_h / 2
    local preset_cy = slider_cy + slider_row_h / 2 + gap_sp + preset_row_h / 2

    -- title
    elements["speed_menu_title"].visible = true
    lo = add_layout("speed_menu_title")
    lo.geometry = {x = panel_x + pad_x, y = title_cy, an = 4, w = panel_w - 2 * pad_x, h = title_h}
    lo.layer = 62
    lo.style = "{\\bord0\\1c&H999999&\\fs13\\fn" .. user_opts.font .. "}"

    -- big current speed readout
    elements["speed_menu_value"].visible = true
    lo = add_layout("speed_menu_value")
    lo.geometry = {x = panel_x + panel_w / 2, y = value_cy, an = 5, w = panel_w - 2 * pad_x, h = value_h}
    lo.layer = 62
    lo.style = "{\\bord0\\1c&HFFFFFF&\\fs30\\b1\\fn" .. user_opts.font .. "}"

    -- slider row: [-]  slider  [+]
    local btn_size = 26
    local btn_gap = 8
    local dec_cx = panel_x + pad_x + btn_size / 2
    local inc_cx = panel_x + panel_w - pad_x - btn_size / 2
    local slider_x1 = panel_x + pad_x + btn_size + btn_gap
    local slider_x2 = panel_x + panel_w - pad_x - btn_size - btn_gap
    local slider_w = slider_x2 - slider_x1
    local slider_cx = slider_x1 + slider_w / 2

    elements["speed_dec"].visible = true
    lo = add_layout("speed_dec")
    lo.geometry = {x = dec_cx, y = slider_cy, an = 5, w = btn_size, h = btn_size}
    lo.layer = 62
    lo.style = "{\\bord0\\1c&HFFFFFF&\\fs20\\fn" .. user_opts.font .. "}"
    elements["speed_dec"].pill_bg = {
        x1 = dec_cx - btn_size / 2, y1 = slider_cy - btn_size / 2,
        x2 = dec_cx + btn_size / 2, y2 = slider_cy + btn_size / 2,
        radius = btn_size / 2,
        color = "#3D3D3D",
    }

    elements["speed_inc"].visible = true
    lo = add_layout("speed_inc")
    lo.geometry = {x = inc_cx, y = slider_cy, an = 5, w = btn_size, h = btn_size}
    lo.layer = 62
    lo.style = "{\\bord0\\1c&HFFFFFF&\\fs20\\fn" .. user_opts.font .. "}"
    elements["speed_inc"].pill_bg = {
        x1 = inc_cx - btn_size / 2, y1 = slider_cy - btn_size / 2,
        x2 = inc_cx + btn_size / 2, y2 = slider_cy + btn_size / 2,
        radius = btn_size / 2,
        color = "#3D3D3D",
    }

    -- slider track background
    elements["speed_slider_bg"].visible = true
    lo = add_layout("speed_slider_bg")
    lo.geometry = {x = slider_cx, y = slider_cy, an = 5, w = slider_w, h = 4}
    lo.layer = 62
    lo.style = "{\\1c&H5A5A5A&}"
    lo.box.radius = 2
    lo.alpha[1] = 0

    -- slider (progress + draggable handle)
    elements["speed_slider"].visible = true
    lo = add_layout("speed_slider")
    lo.geometry = {x = slider_cx, y = slider_cy, an = 5, w = slider_w, h = 14}
    lo.layer = 63
    lo.style = "{\\1c&H" .. osc_color_convert(accent) .. "&}"
    lo.slider.handle_color = accent
    lo.slider.radius = 2
    lo.slider.gap = 5

    -- preset buttons (simple text options in a horizontal row)
    local inner_w = panel_w - 2 * pad_x
    local n = #presets
    local slot_w = inner_w / n
    for i = 1, n do
        local name = "speed_preset_" .. i
        local cx = panel_x + pad_x + slot_w / 2 + (i - 1) * slot_w
        elements[name].visible = true
        lo = add_layout(name)
        lo.geometry = {x = cx, y = preset_cy, an = 5, w = slot_w, h = preset_row_h}
        lo.layer = 63
        lo.style = "{\\bord0\\fs13\\fn" .. user_opts.font .. "}"
    end
end

-- Default layout
layouts["default"] = function ()
    local no_title = not user_opts.show_title
    local no_chapter = not user_opts.show_chapter_title
    local chapter_index = user_opts.show_chapter_title and (state.chapter or -1) >= 0
    local chapter_h = (no_chapter or not chapter_index) and 0 or user_opts.chapter_title_font_size
    local chapter_offset = (no_chapter or not chapter_index) and 0 or user_opts.chapter_title_offset
    chapter_offset = user_opts.chapter_above_title and user_opts.chapter_above_title_offset or chapter_offset
    local title_h = no_title and 0 or user_opts.title_font_size
    local title_offset = (no_chapter or not chapter_index or user_opts.chapter_above_title) and user_opts.title_offset or user_opts.title_with_chapter_offset
    title_offset = no_title and 0 or title_offset
    local title_and_chapter_h_with_offset = chapter_h + chapter_offset + title_h + title_offset

    local chapter_skip_buttons = user_opts.chapter_skip_buttons and next(state.chapter_list) ~= nil
    outeroffset = (chapter_skip_buttons and 0 or 100) + (user_opts.jump_buttons and 0 or 100)

    if title_and_chapter_h_with_offset == 0 then
        -- add some top padding if both title and chapter aren't displayed
        local timecodes_above = osc_param.playresx < (user_opts.portrait_window_trigger - outeroffset
            - (user_opts.playlist_button and (not user_opts.hide_empty_playlist_button or state.playlist_count > 1) and 0 or 100)
            - (state.sub_track_count > 0 and 0 or 100)
            - (state.audio_track_count > 0 and 0 or 100))
        title_and_chapter_h_with_offset = timecodes_above
            and math.max(user_opts.osc_height * 0.2, user_opts.time_codes_offset + user_opts.title_offset + user_opts.time_font_size)
            or user_opts.osc_height * 0.2
    end

    local osc_h = user_opts.osc_height + title_and_chapter_h_with_offset
    local posX, posY, refX, refY = begin_osc_layout(osc_h)

    -- osc background
    setup_bg_elements(posX, posY, osc_param.playresx, osc_h, user_opts.fade_transparency_strength, user_opts.window_fade_transparency_strength)

    -- seekbar
    setup_seekbar(refX, refY, refY - user_opts.osc_height)

    local audio_track = state.audio_track_count > 0
    local subtitle_track = state.sub_track_count > 0
    local ontop_button = user_opts.ontop_button and not (window_controls_enabled() and user_opts.ontop_in_topbar and state.ontop)
    local playlist_button = user_opts.playlist_button and (not user_opts.hide_empty_playlist_button or state.playlist_count > 1)

    local offset = user_opts.jump_buttons and 60 or 0
    local narrow_win = osc_param.playresx < (
        user_opts.portrait_window_trigger
        - outeroffset
        - (playlist_button and 0 or 100)
        - (subtitle_track and 0 or 100)
        - (audio_track and 0 or 100)
    )

    local time_codes_width = get_time_codes_width(osc_styles.time)
    local chapter_title_y, title_y
    if user_opts.chapter_above_title then
        title_y = user_opts.osc_height + title_offset
        chapter_title_y = title_y + title_h + chapter_offset
    else
        chapter_title_y = user_opts.osc_height + chapter_offset
        title_y = (no_chapter or not chapter_index) and (user_opts.osc_height + title_offset) or (chapter_title_y + chapter_h + user_opts.title_with_chapter_offset)
    end

    -- osc title + chapter title
    local title_w = (no_chapter or not chapter_index or user_opts.chapter_above_title) and (osc_param.playresx - 60 - time_codes_width) or (osc_param.playresx - 50)
    local chapter_title_w = narrow_win and (osc_param.playresx - time_codes_width - 60) or (osc_param.playresx - 60)
    setup_title_and_chapter(title_y, title_w, 25, chapter_title_y, chapter_title_w, 26)

    -- left side buttons
    local pos = {left = 37, right = osc_param.playresx - 37}
    local left, right = make_side_buttons({
        style = osc_styles.control_3,
        step = 45,
        row_y = user_opts.osc_height / 2,
        adjust_right = true,
        pos = pos,
    })

    if playlist_button then left("playlist", THRESHOLD.playlist) end
    if audio_track and user_opts.audio_tracks_button then left("audio_track", THRESHOLD.audio) end
    if subtitle_track and user_opts.subtitles_button then left("sub_track", THRESHOLD.subs) end

    if audio_track and user_opts.volume_control then
        left("vol_ctrl", THRESHOLD.volume, nil, 20)
        local vol_vis = (osc_param.playresx >= user_opts.hide_volume_bar_trigger - outeroffset)
        setup_volumebar(pos, user_opts.osc_height / 2, vol_vis, 12)
    end

    -- time codes
    local auto_hide_volbar = (audio_track and user_opts.volume_control) and osc_param.playresx < (user_opts.hide_volume_bar_trigger - outeroffset)
    local time_codes_x = pos.left
        - (auto_hide_volbar and 67 or 0) -- window width with audio track and elements
        - (audio_track and not user_opts.volume_control and 12 or 0) -- audio track with no elements
        - (not audio_track and 12 or 0) -- remove excess space
    local time_codes_y = user_opts.time_codes_offset + (user_opts.osc_height / 2)
    if narrow_win then
        -- try to vertically align time codes to the baseline of title/chapter
        if not user_opts.show_title and not user_opts.show_chapter_title then
            time_codes_y = user_opts.time_codes_offset + user_opts.osc_height + user_opts.title_offset
        elseif no_chapter or not chapter_index or user_opts.chapter_above_title then
            time_codes_y = title_y + ((title_h - user_opts.time_font_size) * 0.25)
        else
            time_codes_y = chapter_title_y
            if chapter_h ~= user_opts.time_font_size then
                time_codes_y = time_codes_y - ((user_opts.time_font_size - chapter_h) * 0.25)
            end
        end
    end
    elements["time_codes"].visible = (state.duration or 0) > 0
    lo = add_layout("time_codes")
    lo.geometry = {x = (narrow_win and (osc_param.playresx - 25) or time_codes_x), y = refY - time_codes_y, an = (narrow_win and 3 or 4), w = time_codes_width, h = user_opts.time_font_size}
    lo.layer = 48
    lo.alpha[3] = 0
    lo.style = osc_styles.time

    -- center buttons
    if user_opts.track_nextprev_buttons then
        elements["playlist_prev"].visible = (state.playlist_count > 1 or contains(user_opts.buttons_always_active, "playlist_prev")) and (osc_param.playresx >= THRESHOLD.prevnext - outeroffset)
        lo = add_layout("playlist_prev")
        lo.geometry = {x = refX - (60 + (chapter_skip_buttons and 60 or 0)) - offset, y = refY - (user_opts.osc_height / 2), an = 5, w = 30, h = 24}
        lo.style = osc_styles.control_2
    end

    if chapter_skip_buttons then
        elements["chapter_prev"].visible = osc_param.playresx >= THRESHOLD.chapter - outeroffset
        lo = add_layout("chapter_prev")
        lo.geometry = {x = refX - 60 - offset, y = refY - (user_opts.osc_height / 2), an = 5, w = 30, h = 24}
        lo.style = osc_styles.control_2
    end

    if user_opts.jump_buttons then
        lo = add_layout("jump_backward")
        lo.geometry = {x = refX - 60, y = refY - (user_opts.osc_height / 2), an = 5, w = 30, h = 24}
        lo.style = osc_styles.control_2
    end

    lo = add_layout("play_pause")
    lo.geometry = {x = refX, y = refY - (user_opts.osc_height / 2), an = 5, w = 45, h = 28}
    lo.style = osc_styles.control_1

    if user_opts.jump_buttons then
        lo = add_layout("jump_forward")
        lo.geometry = {x = refX + 60, y = refY - (user_opts.osc_height / 2), an = 5, w = 30, h = 24}
        lo.style = osc_styles.control_2
    end

    if chapter_skip_buttons then
        elements["chapter_next"].visible = osc_param.playresx >= THRESHOLD.chapter - outeroffset
        lo = add_layout("chapter_next")
        lo.geometry = {x = refX + 60 + offset, y = refY - (user_opts.osc_height / 2), an = 5, w = 30, h = 24}
        lo.style = osc_styles.control_2
    end

    if user_opts.track_nextprev_buttons then
        elements["playlist_next"].visible = (state.playlist_count > 1 or contains(user_opts.buttons_always_active, "playlist_next")) and (osc_param.playresx >= THRESHOLD.prevnext - outeroffset)
        lo = add_layout("playlist_next")
        lo.geometry = {x = refX + (60 + (chapter_skip_buttons and 60 or 0)) + offset, y = refY - (user_opts.osc_height / 2), an = 5, w = 30, h = 24}
        lo.style = osc_styles.control_2
    end

    -- right side buttons
    right("fullscreen", THRESHOLD.fullscreen, user_opts.fullscreen_button)
    right("info", THRESHOLD.info, user_opts.info_button)
    right("ontop", THRESHOLD.ontop, user_opts.ontop_button and not (window_controls_enabled() and user_opts.ontop_in_topbar and state.ontop))
    right("screenshot", THRESHOLD.screenshot, user_opts.screenshot_button)
    right("file_loop", THRESHOLD.file_loop, user_opts.loop_button)
    right("shuffle", THRESHOLD.shuffle, user_opts.shuffle_button)
    right("speed", THRESHOLD.speed, user_opts.speed_button, osc_styles.speed, 42)
    right("download", THRESHOLD.download, state.is_url and user_opts.download_button)

    if user_opts.cache_info then
        right("cache_info", THRESHOLD.cache, user_opts.cache_info, osc_styles.cache, user_opts.cache_info_speed and 70 or 45)
        lo.geometry.x  = lo.geometry.x + 7
        lo.geometry.an = 6
        lo.alpha[3] = 0
    end

    -- speed menu panel (YouTube-style)
    layout_speed_menu()
end

layouts["compact"] = function ()
    local chapter_index = (state.chapter or -1) >= 0
    local no_title = not user_opts.show_title
    local no_chapter = not user_opts.show_chapter_title
    local chapter_h = (no_chapter or not chapter_index) and 0 or user_opts.chapter_title_font_size
    local chapter_offset = (no_chapter or not chapter_index) and 0 or user_opts.chapter_title_offset
    chapter_offset = user_opts.chapter_above_title and user_opts.chapter_above_title_offset or chapter_offset
    local title_h = no_title and 0 or user_opts.title_font_size
    local title_offset = (no_chapter or not chapter_index or user_opts.chapter_above_title) and user_opts.title_offset or user_opts.title_with_chapter_offset
    title_offset = no_title and 0 or title_offset
    local title_and_chapter_h_with_offset = chapter_h + chapter_offset + title_h + title_offset

    if title_and_chapter_h_with_offset == 0 then
        -- add some top padding if both title and chapter aren't displayed
        title_and_chapter_h_with_offset = user_opts.osc_height * 0.2
    end

    local osc_h = user_opts.osc_height + title_and_chapter_h_with_offset
    local posX, posY, refX, refY = begin_osc_layout(osc_h)

    -- osc background
    setup_bg_elements(posX, posY, osc_param.playresx, osc_h, user_opts.fade_transparency_strength, user_opts.window_fade_transparency_strength)

    -- seekbar
    setup_seekbar(refX, refY, refY - user_opts.osc_height)

    local chapter_title_y, title_y
    if user_opts.chapter_above_title then
        title_y = user_opts.osc_height + title_offset
        chapter_title_y = title_y + title_h + chapter_offset
    else
        chapter_title_y = user_opts.osc_height + chapter_offset
        title_y = (no_chapter or not chapter_index) and (user_opts.osc_height + title_offset) or (chapter_title_y + chapter_h + user_opts.title_with_chapter_offset)
    end

    -- osc title + chapter title
    setup_title_and_chapter(title_y, osc_param.playresx - 50, 25, chapter_title_y, osc_param.playresx - 60, 25)

    -- left side buttons
    local pos = {left = 37, right = osc_param.playresx - 37}
    local left, right = make_side_buttons({
        style = osc_styles.control_2,
        step = 45,
        row_y = user_opts.osc_height / 2,
        pos = pos,
    })

    left("play_pause", 200)

    local pl_count = state.playlist_count
    local pl_pos = state.playlist_pos_1

    if user_opts.track_nextprev_buttons then
        left("playlist_prev", 550, nil, nil, nil, pl_pos > 1)
        left("playlist_next", 550, nil, nil, nil, pl_pos < pl_count)
    end

    if user_opts.jump_buttons then
        left("jump_backward", 700, 30)
        left("jump_forward", 700, 30)
    end

    if state.audio_track_count > 0 and user_opts.volume_control then
        left("vol_ctrl", 800, nil, 20)
        local vol_vis = osc_param.playresx >= 900
        setup_volumebar(pos, user_opts.osc_height / 2, vol_vis, 12)
    end

    -- right side buttons
    right("fullscreen", 300, user_opts.fullscreen_button)
    right("ontop", 400, user_opts.ontop_button and not (window_controls_enabled() and user_opts.ontop_in_topbar and state.ontop))
    right("sub_track", 500, user_opts.subtitles_button and state.sub_track_count > 0)
    right("audio_track", 600, user_opts.audio_tracks_button and state.audio_track_count > 0)
    right("playlist", 300, user_opts.playlist_button)
    right("download", 800, state.is_url and user_opts.download_button)
    right("speed", 800, user_opts.speed_button, osc_styles.speed, 42)

    -- time codes
    local time_codes_width = get_time_codes_width(osc_styles.time)
    elements["time_codes"].visible = (state.duration or 0) > 0
    lo = add_layout("time_codes")
    lo.geometry = {x = pos.right + 20, y = refY - (user_opts.osc_height / 2), an = 6, w = time_codes_width, h = 20}
    lo.layer = 48
    lo.alpha[3] = 0
    lo.style = osc_styles.time

    -- speed menu panel (YouTube-style)
    layout_speed_menu()
end

layouts["mini"] = function ()
    local osc_height = 30
    local first_row_y = 25
    local second_row_y = 25
    local osc_offset = first_row_y + second_row_y

    local osc_h = osc_height + osc_offset
    local posX, posY, refX, refY = begin_osc_layout(osc_h)

    -- osc background
    setup_bg_elements(posX, posY, osc_param.playresx, osc_h, user_opts.fade_transparency_strength, user_opts.window_fade_transparency_strength)

    -- seekbar
    setup_seekbar(refX, refY, refY - first_row_y - second_row_y)

    -- left side buttons
    local pos = {left = 37, right = osc_param.playresx - 37}
    local left, right = make_side_buttons({
        style = osc_styles.control_mini,
        step = 35,
        row_y = first_row_y,
        h = 20,
        pos = pos,
    })

    left("play_pause", 200)

    local pl_count = state.playlist_count
    local pl_pos = state.playlist_pos_1

    if user_opts.track_nextprev_buttons then
        left("playlist_prev", 350, nil, nil, nil, pl_pos > 1)
        left("playlist_next", 350, nil, nil, nil, pl_pos < pl_count)
    end

    if user_opts.jump_buttons then
        left("jump_backward", 450, 30)
        left("jump_forward", 450, 30)
    end

    if state.audio_track_count > 0 and user_opts.volume_control then
        left("vol_ctrl", 500, nil, 20)
        local vol_vis = osc_param.playresx >= 650
        setup_volumebar(pos, first_row_y, vol_vis, 10)
    end

    -- right side buttons
    right("fullscreen", 250, user_opts.fullscreen_button)
    right("ontop", 300, user_opts.ontop_button and not (window_controls_enabled() and user_opts.ontop_in_topbar and state.ontop))
    right("sub_track", 400, user_opts.subtitles_button and state.sub_track_count > 0)
    right("audio_track", 500, user_opts.audio_tracks_button and state.audio_track_count > 0)
    right("playlist", 600, user_opts.playlist_button)
    right("download", 700, state.is_url and user_opts.download_button)
    right("speed", 700, user_opts.speed_button, osc_styles.speed, 42)

    -- time codes
    local time_codes_width = get_time_codes_width(osc_styles.time)
    elements["time_codes"].visible = (state.duration or 0) > 0
    lo = add_layout("time_codes")
    lo.geometry = {x = pos.right, y = refY - first_row_y, an = 6, w = time_codes_width, h = 20}
    lo.layer = 48
    lo.alpha[3] = 0
    lo.style = osc_styles.time

    -- speed menu panel (YouTube-style)
    layout_speed_menu()
end

layouts["seekbar"] = function ()
    local osc_height = 30
    local first_row_y = 25
    local second_row_y = 15
    local osc_offset = first_row_y + second_row_y

    local osc_h = osc_height + osc_offset
    local posX, posY, refX, refY = begin_osc_layout(osc_h)

    -- osc background
    setup_bg_elements(posX, posY, osc_param.playresx, osc_h, user_opts.fade_transparency_strength, user_opts.window_fade_transparency_strength)

    -- seekbar
    setup_seekbar(refX, refY, refY - first_row_y)

    -- time codes
    local time_codes_width = get_time_codes_width(osc_styles.time)
    elements["time_codes"].visible = (state.duration or 0) > 0
    lo = add_layout("time_codes")
    lo.geometry = {x = osc_param.playresx - 25, y = refY - first_row_y - second_row_y, an = 3, w = time_codes_width, h = user_opts.time_font_size}
    lo.layer = 48
    lo.alpha[3] = 0
    lo.style = osc_styles.time
end

layouts["modern-image"] = function ()
    local posX, posY, refX, refY = begin_osc_layout(50)

    -- osc background
    setup_bg_elements(posX, posY, osc_param.playresx, 50, user_opts.fade_transparency_strength, user_opts.window_fade_transparency_strength)

    local track_nextprev_buttons = user_opts.track_nextprev_buttons and state.playlist_count > 1
    local fullscreen_button = user_opts.fullscreen_button
    local info_button = user_opts.info_button
    local ontop_button = user_opts.ontop_button and not (window_controls_enabled() and user_opts.ontop_in_topbar and state.ontop)
    local playlist_button = user_opts.playlist_button and (not user_opts.hide_empty_playlist_button or state.playlist_count > 1)
    local zoom_control = user_opts.zoom_control

    local ne
    -- left side buttons are placed at absolute x (no stepping), so they keep a
    -- local helper; right side buttons use the shared factory.
    local function left_side_button(name, x, min_w, w, style)
        elements[name].visible = osc_param.playresx >= min_w
        lo = add_layout(name)
        lo.geometry = {x = x, y = refY - (user_opts.osc_height / 2), an = 5, w = w or 24, h = 24}
        lo.style = style or osc_styles.control_2
    end

    local pos = {left = 37, right = osc_param.playresx - 37}
    local _, right = make_side_buttons({
        style = osc_styles.control_3,
        step = 45,
        row_y = user_opts.osc_height / 2,
        pos = pos,
    })

    -- left side
    if playlist_button then left_side_button("playlist", 25, 250, nil, osc_styles.control_3) end

    if track_nextprev_buttons then
        left_side_button("playlist_prev", 60 - (playlist_button and 0 or 25), 250)
        left_side_button("playlist_next", 90 - (playlist_button and 0 or 25), 250)
    end

    if zoom_control then
        local zoom_vis = osc_param.playresx >= 300
        local zx = 130 - (playlist_button and 0 or 25) - (track_nextprev_buttons and 0 or 70)

        left_side_button("zoom_out_icon", zx, 300, 30)

        ne = new_element("zoom_control_bg", "box")
        ne.visible = zoom_vis
        lo = add_layout("zoom_control_bg")
        lo.geometry = {x = zx + 25, y = refY - (user_opts.osc_height / 2), an = 4, w = 80, h = 4}
        lo.layer = 15
        lo.alpha[1] = 128
        lo.style = osc_styles.volumebar_bg
        lo.box.radius = user_opts.slider_rounded_corners and 2 or 0

        elements["zoom_control"].visible = zoom_vis
        lo = add_layout("zoom_control")
        lo.geometry = {x = zx + 25, y = refY - (user_opts.osc_height / 2), an = 4, w = 80, h = 10}
        lo.style = osc_styles.volumebar_fg
        lo.slider.handle_color = user_opts.side_buttons_color
        lo.slider.radius = user_opts.slider_rounded_corners and 2 or 0
        lo.slider.gap = 3
        lo.slider.tooltip_an = 2

        left_side_button("zoom_in_icon", zx + 130, 300, 30)
    end

    -- right side
    if fullscreen_button then right("fullscreen", 350) end
    if info_button then right("info", 400) end
    if ontop_button then right("ontop", 450) end
    if user_opts.download_button then right("download", 500, state.is_url) end
end

local function toggle_speed_menu()
    state.speed_menu_open = not state.speed_menu_open
    request_init()
end

local function close_speed_menu()
    if state.speed_menu_open then
        state.speed_menu_open = false
        request_init()
    end
end

-- Accessor: returns the private layouts table.
local function get_layouts()
    return layouts
end

return {
    window_controls = window_controls,
    get_speed_presets = get_speed_presets,
    toggle_speed_menu = toggle_speed_menu,
    close_speed_menu = close_speed_menu,
    get_layouts = get_layouts,
}
