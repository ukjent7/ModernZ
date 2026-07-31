-- modernz :: modules/geometry_utils.lua
-- Coordinate math: mouse position (real <-> virtual ASS coordinates), hitbox
-- geometry, and slider value <-> position conversion.

local core = require("modules.core")
local state = core.state
local osc_param = core.osc_param

-- scale factor for translating between real and virtual ASS coordinates
local function get_virt_scale_factor()
    if state.osd_dimensions.w == 0 or state.osd_dimensions.h == 0 then
        return 0, 0
    end
    return osc_param.playresx / state.osd_dimensions.w,
           osc_param.playresy / state.osd_dimensions.h
end

local function recently_touched()
    if state.touchtime == nil then
        return false
    end
    return state.touchtime + 1 >= mp.get_time()
end

-- return mouse position in virtual ASS coordinates (playresx/y)
local function get_virt_mouse_pos()
    if recently_touched() then
        local sx, sy = get_virt_scale_factor()
        return state.last_touchX * sx, state.last_touchY * sy
    elseif state.mouse_in_window then
        local sx, sy = get_virt_scale_factor()
        local x, y = mp.get_mouse_pos()
        return x * sx, y * sy
    else
        return -1, -1
    end
end

-- Last mouse area set per name. render() calls set_virt_mouse_area for the
-- showhide areas every tick; skipping unchanged updates avoids the mpv IPC
-- round-trip. The scale factors are part of the key so a window resize (same
-- virtual coords, different scale) still triggers an update.
local last_areas = {}

local function set_virt_mouse_area(x0, y0, x1, y1, name)
    local sx, sy = get_virt_scale_factor()
    local prev = last_areas[name]
    if prev and prev.x0 == x0 and prev.y0 == y0 and prev.x1 == x1 and prev.y1 == y1
        and prev.sx == sx and prev.sy == sy then
        return
    end
    last_areas[name] = {x0 = x0, y0 = y0, x1 = x1, y1 = y1, sx = sx, sy = sy}
    mp.set_mouse_area(x0 / sx, y0 / sy, x1 / sx, y1 / sy, name)
end

local function scale_value(x0, x1, y0, y1, val)
    -- degenerate domain: the whole range collapses to a single point, so the
    -- value is the coordinate at that point (avoids a division by zero that
    -- would otherwise produce inf/NaN in downstream slider math)
    if x1 == x0 then return y0 end
    local m = (y1 - y0) / (x1 - x0)
    local b = y0 - (m * x0)
    return (m * val) + b
end

-- returns the position of an object on a one-dimensional axis,
-- from 0..1 (object to the "left") to 1..0 (object to the "right"), taking margin into account.
local function get_align(align, frame, obj, margin)
    return (frame / 2) + (((frame / 2) - margin - (obj / 2)) * align)
end

-- returns hitbox spanning coordinates (top left, bottom right corner)
-- according to alignment
local function get_hitbox_coords(x, y, an, w, h)
    local alignments = {
      [1] = function () return x, y-h, x+w, y end,
      [2] = function () return x-(w/2), y-h, x+(w/2), y end,
      [3] = function () return x-w, y-h, x, y end,

      [4] = function () return x, y-(h/2), x+w, y+(h/2) end,
      [5] = function () return x-(w/2), y-(h/2), x+(w/2), y+(h/2) end,
      [6] = function () return x-w, y-(h/2), x, y+(h/2) end,

      [7] = function () return x, y, x+w, y+h end,
      [8] = function () return x-(w/2), y, x+(w/2), y+h end,
      [9] = function () return x-w, y, x, y+h end,
    }

    return alignments[an]()
end

local function get_element_hitbox(element)
    return element.hitbox.x1, element.hitbox.y1, element.hitbox.x2, element.hitbox.y2
end

local function mouse_hit_coords(bX1, bY1, bX2, bY2)
    local mX, mY = get_virt_mouse_pos()
    return (mX >= bX1 and mX <= bX2 and mY >= bY1 and mY <= bY2)
end

local function mouse_hit(element)
    return mouse_hit_coords(get_element_hitbox(element))
end

local function mouse_in_area(names)
    if type(names) == "string" then names = {names} end
    for _, name in ipairs(names) do
        for _, cords in ipairs(osc_param.areas[name] or {}) do
            if mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2) then
                return true
            end
        end
    end
    return false
end

local function limit_range(min, max, val)
    return math.max(min, math.min(max, val))
end

-- translate value into element coordinates
local function get_slider_ele_pos_for(element, val)
    local ele_pos = scale_value(
        element.slider.min.value, element.slider.max.value,
        element.slider.min.ele_pos, element.slider.max.ele_pos,
        val)

    return limit_range(element.slider.min.ele_pos, element.slider.max.ele_pos, ele_pos)
end

-- translates global (mouse) coordinates to value
local function get_slider_value_at(element, glob_pos)
    if element then
        local val = scale_value(
            element.slider.min.glob_pos, element.slider.max.glob_pos,
            element.slider.min.value, element.slider.max.value,
            glob_pos)

        return limit_range(element.slider.min.value, element.slider.max.value, val)
    end
    -- fall back incase of loading errors
    return 0
end

-- get value at current mouse position
local function get_slider_value(element)
    return get_slider_value_at(element, get_virt_mouse_pos())
end

local function add_area(name, x1, y1, x2, y2)
    -- create area if needed
    if osc_param.areas[name] == nil then
        osc_param.areas[name] = {}
    end
    table.insert(osc_param.areas[name], {x1=x1, y1=y1, x2=x2, y2=y2})
end

return {
    get_virt_scale_factor = get_virt_scale_factor,
    get_virt_mouse_pos = get_virt_mouse_pos,
    set_virt_mouse_area = set_virt_mouse_area,
    scale_value = scale_value,
    get_align = get_align,
    get_hitbox_coords = get_hitbox_coords,
    get_element_hitbox = get_element_hitbox,
    mouse_hit_coords = mouse_hit_coords,
    mouse_hit = mouse_hit,
    mouse_in_area = mouse_in_area,
    limit_range = limit_range,
    get_slider_ele_pos_for = get_slider_ele_pos_for,
    get_slider_value = get_slider_value,
    add_area = add_area,
}
