-- modernz :: modules/ass_utils.lua
-- ASS drawing helpers: alpha blending/animation and small shape primitives
-- (tooltips, circles, rounded rects/hexagons).

local core = require("modules.core")
local state = core.state

local user_opts = require("modules.options")

local _styles = require("modules.styles")
local osc_styles = _styles.get_osc_styles()
local _locale = require("modules.locale")
local bidi = _locale.bidi
local _constants = require("modules.constants")
local TOOLTIP_PAD_H = _constants.TOOLTIP_PAD_H
local TOOLTIP_PAD_V = _constants.TOOLTIP_PAD_V

-- Multiplies two alpha values. This is the standard Porter-Duff "over"
-- compositing formula for the alpha channel: it yields the alpha of (a drawn
-- over b), which is exactly what stacking two ASS layers needs (see
-- CODE_REVIEW 7.6). Rounded to an integer: the result feeds into
-- string.format("%X", ...) below, which requires an integer representation
-- (Lua 5.4 errors on fractional floats), and ASS alpha is an 8-bit value anyway.
local function mult_alpha(alphaA, alphaB)
    return math.floor(255 - (((1-(alphaA/255)) * (1-(alphaB/255))) * 255) + 0.5)
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
    local ph, pv = TOOLTIP_PAD_H, TOOLTIP_PAD_V
    local box_h = fs + 2 * pv
    local min_w = box_h + 2 * ph
    local box_w = math.max(width + 2 * ph, min_w)
    -- draw tooltip box
    ass:new_event()
    ass:append("{\\rDefault\\alpha&H4D&}")
    ass:pos(tx - box_w / 2, ty - fs - pv)
    ass:an(7)
    ass:append(osc_styles.tooltip_box)
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
    -- wrap the label in bidi isolates so mixed-direction text (e.g. time codes
    -- in an RTL locale) renders in a stable order
    ass:append(bidi.fsi .. label .. bidi.pdi)
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

return {
    ass_append_alpha = ass_append_alpha,
    draw_tooltip = draw_tooltip,
    ass_draw_cir_cw = ass_draw_cir_cw,
    ass_draw_rr_h_cw = ass_draw_rr_h_cw,
}
