-- modernz :: modules/rendering.lua
-- Element drawing, tooltips, thumbnails.

-- Half-width of the gap cut around chapter markers on gap-style nibbles.
local GAP_HALF = 1.5

-- Elements whose glyphs must not scale on hover (font-scale tags are stripped).
local NO_FONT_SCALE = { title = true, chapter_title = true, time_codes = true, speed = true, cache_info = true }
-- Elements that never draw a hover background box.
local NO_HOVER_BOX = { title = true, chapter_title = true, time_codes = true, cache_info = true, speed_menu_backdrop = true }

local assdraw = require "mp.assdraw"

local core = require("modules.core")
local state = core.state
local osc_param = core.osc_param
local thumbfast = core.thumbfast

local user_opts = require("modules.options")

local _string_utils = require("modules.string_utils")
local strip_font_scale = _string_utils.strip_font_scale
local _utils = require("modules.utils")
local estimate_text_width = _utils.estimate_text_width
local _geometry_utils = require("modules.geometry_utils")
local get_virt_scale_factor = _geometry_utils.get_virt_scale_factor
local get_virt_mouse_pos = _geometry_utils.get_virt_mouse_pos
local get_element_hitbox = _geometry_utils.get_element_hitbox
local mouse_hit_coords = _geometry_utils.mouse_hit_coords
local mouse_hit = _geometry_utils.mouse_hit
local limit_range = _geometry_utils.limit_range
local get_slider_ele_pos_for = _geometry_utils.get_slider_ele_pos_for
local get_slider_value = _geometry_utils.get_slider_value
local _ass_utils = require("modules.ass_utils")
local ass_append_alpha = _ass_utils.ass_append_alpha
local draw_tooltip = _ass_utils.draw_tooltip
local ass_draw_cir_cw = _ass_utils.ass_draw_cir_cw
local _styles = require("modules.styles")
local osc_color_convert = _styles.osc_color_convert
local osc_styles = _styles.get_osc_styles()
local hover_effects = _styles.get_hover_effects()
local _elements = require("modules.elements")
local get_elements = _elements.get_elements

-- Reference stays valid: elements is rebuilt in place by prepare_elements().
local elements = get_elements()

-- Per-element cache of the static ASS prefix (style tags + alpha + optional
-- color + static shapes). Every tick rebuilds these even though they only
-- change while the fade animation is running; caching the final string and
-- re-issuing it skips the merge/alpha math on all idle frames (see
-- CODE_REVIEW 5.1). The key covers everything the output depends on, and the
-- cache stays bounded because fade animation values repeat across fades of
-- the same duration. A full dirty-flag system (re-rendering only elements
-- whose state changed) remains future work; this covers the static portion.
local DRAW_CACHE_MAX = 256
local function build_draw_prefix(element, color, anim_override, alpha_override, inverse, tag_prefix, include_static)
    local anim = anim_override or state.animation
    local key = (anim and string.format("%.4f", anim) or "s")
        .. "|" .. tostring(color) .. "|" .. tostring(alpha_override)
        .. "|" .. tostring(inverse) .. "|" .. tostring(tag_prefix)
        .. "|" .. (include_static and "1" or "0")
    local cache = element.draw_cache
    local cached = cache and cache[key]
    if cached then
        local ass = assdraw.ass_new()
        ass:append(cached)
        return ass
    end

    local ass = assdraw.ass_new()
    ass:merge(element.style_ass)
    ass_append_alpha(ass, element.layout.alpha, alpha_override or 0, inverse, anim_override)
    if color then
        ass:append("{" .. (tag_prefix or "\\blur0\\bord0") .. "\\1c&H" .. osc_color_convert(color) .. "&}")
    end
    if include_static then
        ass:merge(element.static_ass)
    end

    if not cache then
        cache = {}
        element.draw_cache = cache
        element.draw_cache_count = 0
    end
    if element.draw_cache_count >= DRAW_CACHE_MAX then
        -- bound memory when many distinct animation values are seen
        for k in pairs(cache) do cache[k] = nil end
        element.draw_cache_count = 0
    end
    cache[key] = ass.text
    element.draw_cache_count = element.draw_cache_count + 1
    return ass
end

local function get_chapter(possec)
    local cl = state.chapter_list  -- sorted, get latest before possec, if any

    for n=#cl,1,-1 do
        if possec >= cl[n].time then
            return cl[n]
        end
    end
end

-- Computes handle position and radius without drawing
-- Returns handle position, radius, and whether the handle is active (hovered or dragged)
local function get_seekbar_handle_pos(element)
    local pos = element.slider.posF()
    if not pos then return 0, 0, false end

    local elem_geo = element.layout.geometry
    local handle_radius = user_opts.seek_handle_size * elem_geo.h / 2
    local handle_x = get_slider_ele_pos_for(element, pos)
    local center_y = elem_geo.h / 2

    local mouse_over_handle = mouse_hit_coords(
        element.hitbox.x1 + handle_x - handle_radius,
        element.hitbox.y1 + center_y - handle_radius,
        element.hitbox.x1 + handle_x + handle_radius,
        element.hitbox.y1 + center_y + handle_radius
    ) and element.enabled

    local is_active = mouse_over_handle or element.state.handle_drag

    if handle_radius > 0 then
        if is_active then
            handle_radius = handle_radius * (user_opts.slider_hover_size / 100)
            handle_x = limit_range(handle_radius, elem_geo.w - handle_radius, handle_x)
        end
        return handle_x, handle_radius, is_active
    end

    return handle_x, 0, false
end

-- Whether the cursor is over the element, honoring its optional hover_box (an
-- enlarged hit area used by the volume control).
local function is_hovered(element)
    local hb = element.hover_box
    return (hb and mouse_hit_coords(hb.x1, hb.y1, hb.x2, hb.y2) or mouse_hit(element))
end

-- Prepares elem_ass for a new draw layer. color may be nil to only reset the
-- context (no color tag); alpha_override/inverse/tag_prefix let callers reuse
-- this for the seekbar-ranges and nibble backgrounds too.
local function begin_draw_layer(element, elem_ass, color, anim_override, alpha_override, inverse, tag_prefix)
    elem_ass:draw_stop()
    elem_ass:merge(build_draw_prefix(element, color, anim_override, alpha_override, inverse, tag_prefix, true))
end

-- Draws a handle on the seekbar using precomputed position and radius
local function draw_seekbar_handle(element, elem_ass, handle_x, handle_radius, anim_override, is_active)
    if handle_radius <= 0 then return end

    local center_y = element.layout.geometry.h / 2
    local slider_lo = element.layout.slider

    local fill_color = slider_lo.handle_color or user_opts.side_buttons_color
    local border_color = slider_lo.handle_border
    local border_thickness = is_active and user_opts.seek_handle_border_hover_size or user_opts.seek_handle_border_size
    local has_border = border_color and border_color ~= "" and border_thickness > 0

    if has_border then
        -- inner_radius is how far the fill circle extends inward from the outer edge
        local inner_radius = handle_radius * (1 - border_thickness)
        -- full circle in border color, then smaller circle in fill color on top
        begin_draw_layer(element, elem_ass, border_color, anim_override)
        ass_draw_cir_cw(elem_ass, handle_x, center_y, handle_radius)
        begin_draw_layer(element, elem_ass, fill_color, anim_override)
        ass_draw_cir_cw(elem_ass, handle_x, center_y, inner_radius)
    else
        -- no border configured, just draw a single solid circle
        begin_draw_layer(element, elem_ass, fill_color, anim_override)
        ass_draw_cir_cw(elem_ass, handle_x, center_y, handle_radius)
    end
end

-- Collects and sorts pixel-space cut positions for gap-style chapter markers, skipping the first marker
local function collect_gap_cuts(element)
    local cuts = {}
    if element.slider.markerF then
        for n, marker in ipairs(element.slider.markerF()) do
            if n > 1 and marker >= element.slider.min.value and marker <= element.slider.max.value then
                cuts[#cuts + 1] = get_slider_ele_pos_for(element, marker)
            end
        end
        table.sort(cuts)
    end
    return cuts
end

-- Draws bar segments split around chapter gaps, stopping at x_max (bar_w for bg, xp for fg).
local function draw_gap_segments(elem_ass, element, gap_half, x_max, slider_lo, elem_geo, radius)
    gap_half = gap_half or GAP_HALF
    local cuts = collect_gap_cuts(element)
    -- clamp x_max back to the nearest gap boundary if it falls inside a gap
    for _, cut in ipairs(cuts) do
        if x_max > cut - gap_half and x_max < cut + gap_half then
            x_max = cut - gap_half
            break
        end
    end
    local seg_start = 0
    for _, cut in ipairs(cuts) do
        if cut >= x_max then break end
        local seg_end = cut - gap_half
        if seg_end > seg_start then
            elem_ass:round_rect_cw(seg_start, slider_lo.gap, seg_end, elem_geo.h - slider_lo.gap,
                (seg_start == 0) and radius or 0, 0)
        end
        seg_start = cut + gap_half
    end
    if x_max > seg_start then
        elem_ass:round_rect_cw(seg_start, slider_lo.gap, x_max, elem_geo.h - slider_lo.gap,
            (seg_start == 0) and radius or 0, (x_max == elem_geo.w) and radius or 0)
    end
end

-- Draws seekbar ranges according to user_opts
local function draw_seekbar_ranges(element, elem_ass, xp, rh, override_alpha, inverse)
    local handle = xp and rh and rh > 0
    xp = xp or 0
    rh = rh or 0
    local slider_lo = element.layout.slider
    local elem_geo = element.layout.geometry
    local seekRanges = element.slider.seekRangesF()
    if not seekRanges then return end
    begin_draw_layer(element, elem_ass, user_opts.seekbar_cache_color, nil, override_alpha or user_opts.seekrangealpha, inverse, "")

    local radius = slider_lo.radius
    local gap_half = GAP_HALF
    local cuts = (slider_lo.nibbles_style == "gap" and element.name == "seekbar") and collect_gap_cuts(element) or {}

    for _, range in pairs(seekRanges) do
        local pstart = math.max(xp, get_slider_ele_pos_for(element, range["start"]) - slider_lo.gap)
        local pend = math.min(elem_geo.w, get_slider_ele_pos_for(element, range["end"]) + slider_lo.gap)

        -- round edge only when cache range reaches start/end
        local r_left = pstart < element.slider.min.ele_pos and radius or 0
        local r_right = pend > element.slider.max.ele_pos and radius or 0

        -- split around chapter gaps then around the handle
        local seg_start = pstart
        for _, cut in ipairs(cuts) do
            local gap_l, gap_r = cut - gap_half, cut + gap_half
            if gap_r > pstart and gap_l < pend then
                local sl, sr = seg_start, math.min(gap_l, pend)
                if handle and (sl < xp + rh and sr > xp - rh) then
                    if sl < xp - rh then elem_ass:round_rect_cw(sl, slider_lo.gap, xp - rh, elem_geo.h - slider_lo.gap, sl == pstart and r_left or 0, 0) end
                    if xp + rh < sr  then elem_ass:round_rect_cw(xp + rh, slider_lo.gap, sr, elem_geo.h - slider_lo.gap, 0, 0) end
                elseif sr > sl then
                    elem_ass:round_rect_cw(sl, slider_lo.gap, sr, elem_geo.h - slider_lo.gap, sl == pstart and r_left or 0, 0)
                end
                seg_start = math.max(gap_r, pstart)
            end
        end
        local sl, sr = seg_start, pend
        local rl = (sl == pstart) and r_left or 0
        if handle and (sl < xp + rh and sr > xp - rh) then
            if sl < xp - rh then elem_ass:round_rect_cw(sl, slider_lo.gap, xp - rh, elem_geo.h - slider_lo.gap, rl, 0) end
            if xp + rh < sr  then elem_ass:round_rect_cw(xp + rh, slider_lo.gap, sr, elem_geo.h - slider_lo.gap, 0, r_right) end
        else
            if sr > sl then elem_ass:round_rect_cw(sl, slider_lo.gap, sr, elem_geo.h - slider_lo.gap, rl, r_right) end
        end
    end
end

-- show visual indicator in seek ranges for ab loop
local function draw_ab_loop_range(element, elem_ass)
    if element.name ~= "seekbar" then return end
    local ab_a = mp.get_property_number("ab-loop-a")
    if not state.duration or not ab_a or ab_a < 0 then return end
    local ab_b = mp.get_property_number("ab-loop-b")
    local slider_lo = element.layout.slider
    local elem_geo = element.layout.geometry
    local ax = get_slider_ele_pos_for(element, ab_a / state.duration * 100)
    local bx = (ab_b and ab_b > ab_a and ab_b <= state.duration) and get_slider_ele_pos_for(element, ab_b / state.duration * 100) or elem_geo.w
    if ax >= bx then return end
    begin_draw_layer(element, elem_ass, user_opts.ab_loop_color)
    elem_ass:rect_cw(ax, slider_lo.gap, bx, elem_geo.h - slider_lo.gap)
end

local function draw_seekbar_nibbles(element, elem_ass)
    local slider_lo = element.layout.slider
    local elem_geo = element.layout.geometry

    if element.slider.markerF == nil or slider_lo.gap <= 0 then
        return
    end

    if slider_lo.nibbles_style == "gap" and element.name == "seekbar" then
        local radius = slider_lo.radius
        local bg_alpha = 128
        begin_draw_layer(element, elem_ass, user_opts.seekbarbg_color, nil, bg_alpha)
        draw_gap_segments(elem_ass, element, GAP_HALF, elem_geo.w, slider_lo, elem_geo, radius)
        return
    end

    local markers = element.slider.markerF()

    if #markers == 0 then return end
    local current_chapter = state.chapter or -1

    -- draw a single nibble at position s
    local function draw_nibble(ass, s)
        if slider_lo.gap >= 5 then
            local bar_h = 3
            if slider_lo.nibbles_top then
                if slider_lo.nibbles_style == "triangle" then
                    ass:move_to(s - 3, slider_lo.gap - 5)
                    ass:line_to(s + 3, slider_lo.gap - 5)
                    ass:line_to(s, slider_lo.gap - 1)
                elseif slider_lo.nibbles_style == "bar" then
                    ass:rect_cw(s - 1, slider_lo.gap - bar_h, s + 1, slider_lo.gap)
                else
                    ass:rect_cw(s - 1, slider_lo.gap - bar_h, s + 1, elem_geo.h - slider_lo.gap)
                end
            end
            if slider_lo.nibbles_bottom then
                if slider_lo.nibbles_style == "triangle" then
                    ass:move_to(s - 3, elem_geo.h - slider_lo.gap + 5)
                    ass:line_to(s, elem_geo.h - slider_lo.gap + 1)
                    ass:line_to(s + 3, elem_geo.h - slider_lo.gap + 5)
                elseif slider_lo.nibbles_style == "bar" then
                    ass:rect_cw(s - 1, elem_geo.h - slider_lo.gap, s + 1, elem_geo.h - slider_lo.gap + bar_h)
                else
                    ass:rect_cw(s - 1, slider_lo.gap, s + 1, elem_geo.h - slider_lo.gap + bar_h)
                end
            end
        else
            if slider_lo.nibbles_top then
                ass:rect_cw(s - 1, 0, s + 1, slider_lo.gap)
            end
            if slider_lo.nibbles_bottom then
                ass:rect_cw(s - 1, elem_geo.h - slider_lo.gap, s + 1, elem_geo.h)
            end
        end
    end

    -- draw non-current chapter nibbles
    local has_non_current = false
    for n, marker in ipairs(markers) do
        if n > 1 and (n - 1) ~= current_chapter and marker >= element.slider.min.value and marker <= element.slider.max.value then
            if not has_non_current then
                begin_draw_layer(element, elem_ass, user_opts.nibble_color)
                has_non_current = true
            end
            draw_nibble(elem_ass, get_slider_ele_pos_for(element, marker))
        end
    end

    -- draw current chapter nibble on top
    if current_chapter > 0 and current_chapter < #markers then
        local marker = markers[current_chapter + 1]
        if marker >= element.slider.min.value and marker <= element.slider.max.value then
            begin_draw_layer(element, elem_ass, user_opts.nibble_current_color)
            draw_nibble(elem_ass, get_slider_ele_pos_for(element, marker))
        end
    end
end

-- Draws tick marks and numeric labels on the speed slider
-- (1x = prominent default marker, 2x-9x = small ticks; odd values labeled with numbers, all above the track)
local function draw_speed_markers(element, elem_ass)
    local slider_lo = element.layout.slider
    local elem_geo = element.layout.geometry
    if slider_lo.gap <= 0 then return end

    local track_top = slider_lo.gap
    local track_bottom = elem_geo.h - slider_lo.gap
    local left = elem_geo.x - elem_geo.w / 2
    local top = elem_geo.y - elem_geo.h / 2

    -- small ticks for 2x-9x (just above the track)
    begin_draw_layer(element, elem_ass, "#999999")
    for v = 2, 9 do
        local x = get_slider_ele_pos_for(element, v)
        elem_ass:rect_cw(x - 0.5, track_top - 4, x + 0.5, track_top - 1)
    end

    -- prominent default marker for 1x (spans across the track)
    begin_draw_layer(element, elem_ass, "#FFFFFF")
    local x1 = get_slider_ele_pos_for(element, 1)
    elem_ass:rect_cw(x1 - 1, track_top - 4, x1 + 1, track_bottom + 3)

    -- numeric labels above the slider (odd values only: 1/3/5/7/9)
    elem_ass:draw_stop()
    for v = 1, 9, 2 do
        local x = get_slider_ele_pos_for(element, v)
        elem_ass:new_event()
        elem_ass:pos(left + x, top - 2)
        elem_ass:an(2)
        ass_append_alpha(elem_ass, element.layout.alpha, 0)
        elem_ass:append("{\\rDefault\\bord0\\fs8\\fn" .. user_opts.font .. "\\1c&H"
            .. osc_color_convert(v == 1 and "#FFFFFF" or "#999999") .. "&}" .. v)
    end
end

-- Draw seekbar progress more accurately
local function draw_seekbar_progress(element, elem_ass)
    local pos = element.slider.posF()
    if not pos then
        return
    end
    local xp = get_slider_ele_pos_for(element, pos)
    local slider_lo = element.layout.slider
    local elem_geo = element.layout.geometry
    local radius = slider_lo.radius

    if slider_lo.nibbles_style == "gap" and element.name == "seekbar" then
        draw_gap_segments(elem_ass, element, GAP_HALF, xp, slider_lo, elem_geo, radius)
    else
        elem_ass:round_rect_cw(0, slider_lo.gap, xp, elem_geo.h - slider_lo.gap, radius)
    end
end

local function render_elements(master_ass, osc_vis, wc_vis)
    local function render_element(n)
        local element = elements[n]

        -- skip elements whose group is not currently visible
        local is_top = element.layout.group == "top"
        if (is_top and not wc_vis) or (not is_top and not osc_vis) then return end

        -- use wc animation for top group elements
        -- use 0 to block fallback to state.animation when wc has no active animation
        local anim_override = nil
        if is_top then
            anim_override = state.wc_animation or 0
        end

        local style_ass = build_draw_prefix(element, nil, anim_override, nil, nil, nil, false)

        if element.eventresponder and (state.active_element == n) then
            -- run render event functions
            if element.eventresponder.render ~= nil then
                element.eventresponder.render(element)
            end
            if mouse_hit(element) then
                -- mouse down styling
                if element.styledown then
                    local down_style = osc_styles.element_down
                    if NO_FONT_SCALE[element.name] then
                        down_style = strip_font_scale(down_style)
                    end
                    style_ass:append(down_style)
                end
                if element.softrepeat and state.mouse_down_counter >= 15 and state.mouse_down_counter % 5 == 0 then
                    element.eventresponder[state.active_event_source.."_down"](element)
                end
                state.mouse_down_counter = state.mouse_down_counter + 1
            end
        end

        local elem_ass = assdraw.ass_new()

        -- Hover background box
        if element.type == "button" and hover_effects.box and not NO_HOVER_BOX[element.name] then
            local is_clickable = element.eventresponder and (
                element.eventresponder["mbtn_left_down"] ~= nil or
                element.eventresponder["mbtn_left_up"] ~= nil
            )
            local hb = element.hover_box
            if is_hovered(element) and is_clickable and element.enabled then
                local hx1, hy1, hx2, hy2
                if hb then hx1, hy1, hx2, hy2 = hb.x1, hb.y1, hb.x2, hb.y2
                else hx1, hy1, hx2, hy2 = get_element_hitbox(element) end
                local pad = element.hover_pad ~= nil and element.hover_pad or 6
                elem_ass:append("{}")
                elem_ass:new_event()
                elem_ass:pos(0, 0)
                elem_ass:an(7)
                local hover_base_alpha = state.mouse_down_counter > 0 and (255 - math.floor(math.max(0, math.min(100, user_opts.button_held_box_alpha)) * 2.55)) or (element.hover_alpha or 0xE6)
                ass_append_alpha(elem_ass, {[1] = hover_base_alpha, [2] = 255, [3] = 255, [4] = 255}, element.layout.alpha[1], nil, anim_override)
                local hover_style = element.hover_color
                    and "{\\blur0\\bord0\\1c&H" .. osc_color_convert(element.hover_color) .. "&}"
                    or osc_styles.hover_bg
                elem_ass:append(hover_style)
                elem_ass:draw_start()
                local hover_radius = element.hover_radius ~= nil and element.hover_radius or 4
                elem_ass:round_rect_cw(hx1 - pad, hy1 - pad, hx2 + pad, hy2 + pad, hover_radius)
                elem_ass:draw_stop()
            end
        end

        -- Pill / capsule background drawn at render time so its color can react
        -- live to state changes (e.g. the active speed preset while dragging the slider)
        if element.type == "button" and element.pill_bg then
            local pb = element.pill_bg
            local pb_color = pb.colorF and pb.colorF() or pb.color
            if pb_color then
                elem_ass:append("{}")
                elem_ass:new_event()
                elem_ass:pos(0, 0)
                elem_ass:an(7)
                ass_append_alpha(elem_ass, {[1] = 0, [2] = 255, [3] = 255, [4] = 255}, element.layout.alpha[1], nil, anim_override)
                elem_ass:append("{\\blur0\\bord0\\1c&H" .. osc_color_convert(pb_color) .. "&}")
                elem_ass:draw_start()
                elem_ass:round_rect_cw(pb.x1, pb.y1, pb.x2, pb.y2, pb.radius or 0)
                elem_ass:draw_stop()
            end
        end

        elem_ass:merge(style_ass)

        if element.type ~= "button" then
            elem_ass:merge(element.static_ass)
        end

        if element.type == "slider" then
            if element.name ~= "persistent_seekbar" then
                local slider_lo = element.layout.slider
                local elem_geo = element.layout.geometry
                local s_min = element.slider.min.value
                local s_max = element.slider.max.value

                draw_seekbar_nibbles(element, elem_ass)
                if element.name == "speed_slider" then draw_speed_markers(element, elem_ass) end

                -- reset context so handle/progress render on top of nibbles
                begin_draw_layer(element, elem_ass, nil, anim_override)

                local handle_x, handle_radius, is_active = get_seekbar_handle_pos(element) -- get handle position/radius
                draw_seekbar_progress(element, elem_ass)
                draw_seekbar_ranges(element, elem_ass, handle_x, handle_radius)
                draw_ab_loop_range(element, elem_ass)
                draw_seekbar_handle(element, elem_ass, handle_x, handle_radius, anim_override, is_active) -- draw handle on top of progress

                elem_ass:draw_stop()

                if element.slider and element.slider.tooltipF ~= nil and element.enabled then
                    local force_seek_tooltip = user_opts.force_seek_tooltip
                        and element.name == "seekbar"
                        and element.eventresponder["mbtn_left_down"]
                        and element.state.mbtnleft
                        and state.mouse_down_counter > 0
                        and state.playing_and_seeking

                    if mouse_hit(element) or force_seek_tooltip then
                        local sliderpos = get_slider_value(element)
                        local tooltiplabel = element.slider.tooltipF(sliderpos)
                        local an = slider_lo.tooltip_an
                        local ty
                        if an == 2 then
                            local seekbar = state.seekbar_element
                            local ref_el = (element.name == "volumebar" and seekbar and seekbar.hitbox) and seekbar or element
                            local image_mode_offset = (ref_el == element) and 10 or 0
                            local anchor_offset = (ref_el == element) and (elem_geo.h / 2) or 0
                            ty = ref_el.hitbox.y1 + anchor_offset - user_opts.tooltip_height_offset - image_mode_offset
                        else
                            ty = element.hitbox.y1 + elem_geo.h / 2 - user_opts.tooltip_height_offset
                        end

                        local tx = get_virt_mouse_pos()
                        local osd_w = state.osd_dimensions.w
                        local r_w, r_h = get_virt_scale_factor()

                        local tooltip_width = estimate_text_width(tooltiplabel, slider_lo.tooltip_style)

                        local chapter_text = nil
                        local chapter_width = 0

                        if osd_w and r_w > 0 then
                            -- Only attempt to fetch and measure chapter logic if this is the seekbar
                            if element.name == "seekbar" and user_opts.chapter_fmt ~= "no" then
                                local dur = state.duration or 0
                                if dur > 0 then
                                    local ch = get_chapter(sliderpos * dur / 100)
                                    if ch and ch.title and ch.title ~= "" then
                                        chapter_text = string.format(user_opts.chapter_fmt, ch.title)
                                        chapter_width = estimate_text_width(chapter_text, slider_lo.tooltip_style)
                                    end
                                end
                            end

                            -- Clamping layer ensures horizontal boundaries are strictly respected
                            if slider_lo.adjust_tooltip or (element.thumbnailable and not thumbfast.disabled) then
                                local max_text_width = math.max(tooltip_width, chapter_width)
                                local margin = 10 * r_w
                                local half_width = max_text_width / 2
                                local min_x = margin + half_width
                                local max_x = osc_param.playresx - margin - half_width
                                tx = math.min(max_x, math.max(min_x, tx))
                            end
                        end

                        if element.name == "seekbar" then
                            state.sliderpos = sliderpos
                        end

                        local tooltip_fs = user_opts.tooltip_font_size
                        local pad_v = 3
                        local gap = 5

                        -- Anchor above tooltip: ty (baseline) - fs (height) - pad_v (tooltip padding) - gap
                        local current_y = ty - tooltip_fs - pad_v - gap

                        -- Thumbfast logic
                        if element.thumbnailable and not thumbfast.disabled and osd_w then
                            local thumb_pad = user_opts.thumbnail_box_padding
                            local thumb_radius = user_opts.thumbnail_box_radius > 0 and user_opts.thumbnail_box_radius or 0

                            local hover_sec = 0
                            if state.duration then hover_sec = state.duration * sliderpos / 100 end

                            local margin_x = 18 / r_w
                            local thumb_x = math.min(osd_w - thumbfast.width - margin_x, math.max(margin_x, tx / r_w - thumbfast.width / 2))
                            thumb_x = math.floor(thumb_x + 0.5)

                            local thumb_y_px = current_y - (thumb_pad * r_h) - (thumbfast.height * r_h)

                            if state.anitype == nil then
                                elem_ass:new_event()
                                elem_ass:append("{\\rDefault}")
                                elem_ass:pos(thumb_x * r_w, thumb_y_px)
                                elem_ass:an(7)
                                elem_ass:append(osc_styles.thumbnail)
                                elem_ass:draw_start()
                                elem_ass:round_rect_cw(-thumb_pad * r_w, -thumb_pad * r_h, (thumbfast.width + thumb_pad) * r_w, (thumbfast.height + thumb_pad) * r_h, thumb_radius)
                                elem_ass:draw_stop()

                                mp.commandv("script-message-to", "thumbfast", "thumb", hover_sec, thumb_x, math.floor(thumb_y_px / r_h + 0.5))
                            end

                            -- Keep tooltips anchored to the thumbnail center even at window edges
                            tx = (thumb_x + thumbfast.width / 2) * r_w
                            an = 2

                            -- Advance anchor above the thumbnail
                            current_y = thumb_y_px - (thumb_pad * r_h) - gap
                        end

                        if chapter_text and r_w > 0 then
                            local chapter_y = current_y - pad_v
                            draw_tooltip(elem_ass, tx, chapter_y, chapter_width, slider_lo.tooltip_style, chapter_text, slider_lo.alpha)
                        end

                        draw_tooltip(elem_ass, tx, ty, tooltip_width, slider_lo.tooltip_style, tooltiplabel, slider_lo.alpha)
                    elseif element.thumbnailable and thumbfast.available then
                        mp.commandv("script-message-to", "thumbfast", "clear")
                    end
                end
            end
        elseif element.type == "button" then
            local buttontext
            if type(element.content) == "function" then
                buttontext = element.content() -- function objects
            elseif element.content ~= nil then
                buttontext = element.content -- text objects
            end

            -- add hover effects
            local button_lo = element.layout.button
            local is_clickable = element.eventresponder and (element.eventresponder["mbtn_left_down"] ~= nil or element.eventresponder["mbtn_left_up"] ~= nil)
            local hovered = mouse_hit(element) and is_clickable and element.enabled and state.mouse_down_counter == 0
            local hoverstyle = button_lo.hoverstyle
            if hovered and (hover_effects.size or hover_effects.color) then
                -- remove font scale tags for these elements, it looks out of place
                if NO_FONT_SCALE[element.name] then
                    hoverstyle = strip_font_scale(hoverstyle)
                end
                elem_ass:append(hoverstyle .. buttontext)
            else
                elem_ass:append(buttontext)
            end

            -- apply blur effect if "glow" is in hover effects
            if hovered and hover_effects.glow then
                local shadow_ass = assdraw.ass_new()
                shadow_ass:merge(style_ass)
                shadow_ass:append("{\\blur" .. user_opts.button_glow_amount .. "}" .. hoverstyle .. buttontext)
                elem_ass:merge(shadow_ass)
            end

            -- add tooltip for button elements
            local seeking_with_force_tooltip = user_opts.force_seek_tooltip and state.mouse_down_counter > 0 and state.playing_and_seeking

            if element.tooltipF ~= nil and element.enabled and not seeking_with_force_tooltip and user_opts.tooltip_hints then
                local hb = element.hover_box
                if is_hovered(element) then
                    local tooltiplabel

                    -- tooltip label
                    if element.enabled then
                        if type(element.tooltipF) == "function" then
                            tooltiplabel = element.tooltipF()
                        else
                            tooltiplabel = element.tooltipF
                        end
                    else
                        tooltiplabel = element.nothingavailable
                    end

                    local tx = hb and (hb.x1 + hb.x2) / 2 or (element.hitbox.x1 + element.hitbox.x2) / 2
                    local seekbar_ref = (state.seekbar_element and state.seekbar_element.hitbox) and state.seekbar_element or element
                    local image_mode_offset = (seekbar_ref == element) and 10 or 0
                    local ty = seekbar_ref.hitbox.y1 - user_opts.tooltip_height_offset - image_mode_offset

                    local osd_w = state.osd_dimensions.w
                    local r_w = get_virt_scale_factor()
                    local tooltip_width = estimate_text_width(tooltiplabel, element.tooltip_style)
                    if osd_w and r_w > 0 then
                        local margin = 10 * r_w
                        tx = math.min(osc_param.playresx - margin - tooltip_width / 2, math.max(margin + tooltip_width / 2, tx))
                    end

                    if tooltiplabel then
                        -- bidi isolation is applied inside draw_tooltip
                        draw_tooltip(elem_ass, tx, ty, tooltip_width, element.tooltip_style, tooltiplabel)
                    end
                end
            end
        end

        master_ass:merge(elem_ass)
    end

    for n = 1, #elements do render_element(n) end
end

local function render_persistent_progress(master_ass)
    local element = state.persistent_seekbar_element
    if not element or not element.layout then return end
    if state.animation or not state.osc_visible then
        local style_ass = build_draw_prefix(element, nil, nil, 0, true, nil, false)

        local elem_ass = assdraw.ass_new()
        elem_ass:merge(style_ass)
        elem_ass:merge(element.static_ass)

        -- draw pos marker
        local pos = element.slider.posF and element.slider.posF()
        local xp = pos and get_slider_ele_pos_for(element, pos) or 0

        draw_seekbar_progress(element, elem_ass)

        if user_opts.persistent_buffer then
            draw_seekbar_ranges(element, elem_ass, xp, 0, nil, true)
        end

        elem_ass:draw_stop()
        master_ass:merge(elem_ass)
    end
end

--
-- Initialisation and Layout
return {
    render_elements = render_elements,
    render_persistent_progress = render_persistent_progress,
}
