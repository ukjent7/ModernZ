-- modernz :: modules/elements.lua
-- Elements are module-owned data, accessed via get_elements() rather than a shared table.

local assdraw = require "mp.assdraw"
local msg = require "mp.msg"

local user_opts = require("modules.options")

local _styles = require("modules.styles")
local osc_styles = _styles.get_osc_styles()

local _utils = require("modules.utils")
local estimate_text_width = _utils.estimate_text_width
local get_hitbox_coords = _utils.get_hitbox_coords
local ass_draw_rr_h_cw = _utils.ass_draw_rr_h_cw

-- Private elements table, owned by this module
local elements = {}

local function prepare_elements()
    -- remove elements without layout or invisible
    local elements2 = {}
    for _, element in pairs(elements) do
        if element.layout ~= nil and element.visible then
            table.insert(elements2, element)
        end
    end
    for k in pairs(elements) do elements[k] = nil end
    for i = 1, #elements2 do elements[i] = elements2[i] end

    local function elem_compare (a, b)
        return a.layout.layer < b.layout.layer
    end

    table.sort(elements, elem_compare)

    for _,element in pairs(elements) do

        local elem_geo = element.layout.geometry

        -- Calculate title and chapter hitbox
        local hitbox_w = elem_geo.w

        if (element.name == "title" or element.name == "chapter_title") and type(element.content) == "function" then
            local width = estimate_text_width(element.content(), osc_styles[element.name])
            if width > 0 then hitbox_w = math.min(width, hitbox_w) end
        end

        -- Calculate the hitbox
        local hitbox_h = elem_geo.h + ((element.name == "volumebar" or element.name == "zoom_control" or element.name == "speed_slider") and 14 or 0)
        local bX1, bY1, bX2, bY2 = get_hitbox_coords(elem_geo.x, elem_geo.y, elem_geo.an, hitbox_w, hitbox_h)
        element.hitbox = {x1 = bX1, y1 = bY1, x2 = bX2, y2 = bY2}

        local style_ass = assdraw.ass_new()

        -- prepare static elements
        style_ass:append("{}") -- hack to troll new_event into inserting a \n
        style_ass:new_event()
        style_ass:pos(elem_geo.x, elem_geo.y)
        style_ass:an(elem_geo.an)
        style_ass:append(element.layout.style)

        element.style_ass = style_ass

        local static_ass = assdraw.ass_new()

        if element.type == "box" then
            --draw box
            static_ass:draw_start()
            ass_draw_rr_h_cw(static_ass, 0, 0, elem_geo.w, elem_geo.h, element.layout.box.radius, element.layout.box.hexagon)
            static_ass:draw_stop()

        elseif element.type == "slider" then
            --draw static slider parts
            local slider_lo = element.layout.slider
            -- calculate positions of min and max points
            element.slider.min.ele_pos = user_opts.seek_handle_size > 0 and (user_opts.seek_handle_size * elem_geo.h / 2) or slider_lo.border
            element.slider.max.ele_pos = elem_geo.w - element.slider.min.ele_pos
            element.slider.min.glob_pos = element.hitbox.x1 + element.slider.min.ele_pos
            element.slider.max.glob_pos = element.hitbox.x1 + element.slider.max.ele_pos

            static_ass:draw_start()
            -- a hack which prepares the whole slider area to allow center placements such like an=5
            static_ass:rect_cw(0, 0, elem_geo.w, elem_geo.h)
            static_ass:rect_ccw(0, 0, elem_geo.w, elem_geo.h)
            -- marker nibbles are drawn dynamically in draw_seekbar_nibbles()
        end

        element.static_ass = static_ass

        -- if the element is supposed to be disabled,
        -- style it accordingly and kill the eventresponders
        if not element.enabled then
            if element.name ~= "seekbar" then
                element.layout.alpha[1] = 215
            end
            -- keep these to display tooltips
            if not (element.name == "sub_track" or element.name == "audio_track" or element.name == "playlist") then
                element.eventresponder = nil
            end
        end

        -- gray out the element if it is toggled off
        if element.off then
            element.layout.alpha[1] = 100
        end
    end
end

--
-- Element Rendering
--

local function new_element(name, type)
    elements[name] = {}
    elements[name].type = type
    elements[name].name = name

    -- add default stuff
    elements[name].eventresponder = {}
    elements[name].visible = true
    elements[name].enabled = true
    elements[name].softrepeat = false
    elements[name].styledown = (type == "button")
    elements[name].state = {}

    if type == "button" then
        elements[name].tooltip_style = osc_styles.tooltip
    elseif type == "slider" then
        elements[name].slider = {min = {value = 0}, max = {value = 100}}
        elements[name].thumbnailable = false
    end

    return elements[name]
end

local function add_layout(name)
    if elements[name] ~= nil then
        -- new layout
        elements[name].layout = {}

        -- set layout defaults
        elements[name].layout.layer = 50
        elements[name].layout.alpha = {[1] = 0, [2] = 255, [3] = 255, [4] = 255}
        elements[name].layout.group = "bottom"

        if elements[name].type == "button" then
            elements[name].layout.button = {
                hoverstyle = osc_styles.element_hover,
            }
        elseif elements[name].type == "slider" then
            -- slider defaults
            elements[name].layout.slider = {
                border = 1,
                gap = 1,
                radius = 0,
                nibbles_top = user_opts.nibbles_top,
                nibbles_bottom = user_opts.nibbles_bottom,
                nibbles_style = user_opts.nibbles_style,
                adjust_tooltip = true,
                tooltip_style = osc_styles.tooltip,
                tooltip_an = 2,
                alpha = {[1] = 0, [2] = 255, [3] = 88, [4] = 255},
                hoverstyle = osc_styles.element_hover:gsub("\\fscx%d+\\fscy%d+", ""), -- font scales messes with handle positions in werid ways
            }
        elseif elements[name].type == "box" then
            elements[name].layout.box = {radius = 0, hexagon = false}
        end

        return elements[name].layout
    else
        msg.error("Can't add_layout to element '"..name.."', doesn't exist.")
    end
end

-- Accessor: returns the private elements table.
local function get_elements()
    return elements
end

-- Clear all elements (called by osc_init on reinit)
local function clear_elements()
    for k in pairs(elements) do elements[k] = nil end
end

return {
    new_element = new_element,
    add_layout = add_layout,
    prepare_elements = prepare_elements,
    get_elements = get_elements,
    clear_elements = clear_elements,
}