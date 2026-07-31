-- modernz :: modules/ass_utils.lua
-- ASS subtitle-drawing helpers: alpha blending/animation and small shape
-- primitives (tooltips, circles, rounded rects/hexagons). Split out of the
-- old monolithic utils.lua so this cohesive group of drawing helpers lives
-- in one place, separate from geometry math and margin management.

local core = require("modules.core")
local state = core.state

local user_opts = require("modules.options")

local _styles = require("modules.styles")
local function get_osc_styles()
    return _styles.get_osc_styles()
end

-- multiplies two alpha values, formular can probably be improved
local function mult_alpha(alphaA, alphaB)
    return 255 - (((1-(alphaA/255)) * (1-(alphaB/255))) * 255)
end

local function ass_append_alpha(ass, alpha, modifier, inverse, anim_override)
    local ar = {}

    for ai, av in ipairs(alpha) do
        av = mult_alpha(av, modifier)
        local animpos = anim_override or state.animation
        if animpos then
            if inverse then
                animpos = 255 - animpos
            end
            av = mult_alpha(av, animpos)
        end
        ar[ai] = av
    end

    ass:append(string.format("{\\1a&H%X&\\2a&H%X&\\3a&H%X&\\4a&H%X&}", ar[1], ar[2], ar[3], ar[4]))
end

-- draw tooltip background box and label
local function draw_tooltip(ass, tx, ty, width, style, label, alpha)
    local fs = user_opts.tooltip_font_size
    local ph, pv = 5, 3
    local box_h = fs + 2 * pv
    local min_w = box_h + 2 * ph
    local box_w = math.max(width + 2 * ph, min_w)
    -- draw tooltip box
    ass:new_event()
    ass:append("{\\rDefault\\alpha&H4D&}")
    ass:pos(tx - box_w / 2, ty - fs - pv)
    ass:an(7)
    ass:append(get_osc_styles().tooltip_box)
    ass:draw_start()
    ass:round_rect_cw(0, 0, box_w, box_h, box_h / 2)
    ass:draw_stop()
    -- add tooltip
    ass:new_event()
    ass:append("{\\rDefault}")
    ass:pos(tx, ty)
    ass:an(2)
    ass:append(style)
    if alpha then ass_append_alpha(ass, alpha, 0) end
    ass:append(label)
end

local function ass_draw_cir_cw(ass, x, y, r)
    ass:round_rect_cw(x-r, y-r, x+r, y+r, r)
end

local function ass_draw_rr_h_cw(ass, x0, y0, x1, y1, r1, hexagon, r2)
    if hexagon then
        ass:hexagon_cw(x0, y0, x1, y1, r1, r2)
    else
        ass:round_rect_cw(x0, y0, x1, y1, r1, r2)
    end
end

-- mult_alpha is used internally only (by ass_append_alpha) and stays as a
-- local function above.
return {
    ass_append_alpha = ass_append_alpha,
    draw_tooltip = draw_tooltip,
    ass_draw_cir_cw = ass_draw_cir_cw,
    ass_draw_rr_h_cw = ass_draw_rr_h_cw,
}
