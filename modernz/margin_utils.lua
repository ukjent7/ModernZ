-- modernz :: modules/margin_utils.lua
-- Video/OSD/subtitle margin management.

local core = require("modules.core")
local state = core.state
local osc_param = core.osc_param

local user_opts = require("modules.options")

local function get_hidetimeout()
    if user_opts.visibility == "always" then
        return -1 -- disable autohide
    end
    return user_opts.hidetimeout
end

local function set_margin_offset(prop, offset)
    if offset > 0 then
        if not state[prop] then
            state[prop] = mp.get_property_number(prop)
        end
        mp.set_property_number(prop, state[prop] + offset)
    elseif state[prop] then
        mp.set_property_number(prop, state[prop])
        state[prop] = nil
    end
end

local function reset_margins()
    -- restore subtitle position if it was changed
    if state.osc_adjusted_subpos ~= nil then
        mp.set_property_number("sub-pos", state.user_subpos)
        state.osc_adjusted_subpos = nil
    end
    set_margin_offset("osd-margin-y", 0)
end

local function update_margins()
    local use_margins = get_hidetimeout() < 0 or user_opts.dynamic_margins
    local top_vis = state.wc_visible
    local bottom_vis = state.osc_visible
    local margins = {
        l = 0,
        r = 0,
        t = (use_margins and top_vis) and osc_param.video_margins.t or 0,
        b = (use_margins and bottom_vis) and osc_param.video_margins.b or 0,
    }

    -- raise amount is based on OSC height
    if user_opts.sub_margins and mp.get_property_native("sid") then
        if margins.b > 0 then
            local raise_percent = margins.b * 100
            -- only raise if subs are low enough that they would overlap the OSC
            if state.user_subpos >= (100 - raise_percent) then
                local adjusted = math.floor((1 - margins.b) * 100)
                if adjusted < 0 then adjusted = state.user_subpos end
                state.osc_adjusted_subpos = adjusted
                mp.set_property_number("sub-pos", adjusted)
            else
                -- sub pos is high; do nothing
                state.osc_adjusted_subpos = nil
            end
        else
            -- restore original sub position
            if state.osc_adjusted_subpos ~= nil then
                mp.set_property_number("sub-pos", state.user_subpos)
                state.osc_adjusted_subpos = nil
            end
        end
    end

    if user_opts.osd_margins then
        local align = mp.get_property("osd-align-y")
        local osd_margin = 0
        if align == "top" and top_vis then
            osd_margin = margins.t
        elseif align == "bottom" and bottom_vis then
            osd_margin = margins.b
        end
        set_margin_offset("osd-margin-y", osd_margin * osc_param.playresy)
    end

    mp.set_property_native("user-data/osc/margins", margins)
end

return {
    get_hidetimeout = get_hidetimeout,
    reset_margins = reset_margins,
    update_margins = update_margins,
}
