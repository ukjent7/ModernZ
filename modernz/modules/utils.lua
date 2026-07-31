-- modernz :: modules/utils.lua
--
-- Remaining after the module split: OSD submission/observation, text-width
-- measurement (and its cache), time-code formatting, cache-range helpers,
-- and window-control detection. Geometry/mouse math moved to
-- geometry_utils.lua, ASS drawing helpers moved to ass_utils.lua, and margin
-- management moved to margin_utils.lua.

local msg = require "mp.msg"

local core = require("modules.core")
local state = core.state
local osc_param = core.osc_param

local user_opts = require("modules.options")

local _constants = require("modules.constants")
local platform = _constants.platform
local UNICODE_MINUS = _constants.UNICODE_MINUS

local _margin_utils = require("modules.margin_utils")
local get_hidetimeout = _margin_utils.get_hidetimeout

-- utils.lua depends on styles.lua for get_time_codes_width(), which needs
-- the current osc_styles table. This is a plain one-directional require:
-- styles.lua no longer requires utils.lua (it gets contains() from
-- string_utils.lua instead), so there is no cycle here.
local _styles = require("modules.styles")
local function get_osc_styles()
    return _styles.get_osc_styles()
end

-- Private text width cache, owned by this module
local text_width_cache = {}

local function kill_animation(anitype_key, anistart_key, animation_key)
    state[anitype_key]   = nil
    state[anistart_key]  = nil
    state[animation_key] = nil
end

local function set_osd(osd, res_x, res_y, text, z)
    if osd.res_x == res_x and osd.res_y == res_y and osd.data == text then
        return
    end
    osd.res_x = res_x
    osd.res_y = res_y
    osd.data = text
    osd.z = z
    osd:update()
end


local function observe_cached(property, callback)
    local key = property:gsub("-", "_")
    mp.observe_property(property, "native", function (_, value)
        state[key] = value
        callback()
    end)
end

local text_measure_osd = mp.create_osd_overlay and mp.create_osd_overlay("ass-events") or nil
if text_measure_osd then
    text_measure_osd.hidden = true
    text_measure_osd.compute_bounds = true
end


local function estimate_text_width(text, style)
    if text == nil then return 0 end
    text = tostring(text)
    if #text == 0 then return 0 end

    -- replace digits with '0' for consistency
    local measure_text = text:gsub("%d", "0")
    local cache_key = measure_text .. (style or "")
    local width = 0

    if text_width_cache[cache_key] then
        return text_width_cache[cache_key]
    end

    if text_measure_osd and text_measure_osd.update then
        text_measure_osd.res_x = osc_param.playresx
        text_measure_osd.res_y = osc_param.playresy
        text_measure_osd.data = (style or "") .. "{\\an7\\pos(0,0)}" .. measure_text

        local bounds = text_measure_osd:update()
        if bounds and bounds.x1 and bounds.x0 then
            -- subtract side-bearing padding that libass adds even at bord0
            local fs = tonumber((style or ""):match("\\fs(%d+%.?%d*)")) or 16
            local bearing_correction = fs * 0.08 * 2
            width = math.max(0, (bounds.x1 - bounds.x0) - bearing_correction)
        end
    end

    text_width_cache[cache_key] = width
    return width
end

-- width of the time codes element
local function get_time_codes_width()
    local dur = state.duration or 0
    local rt_sec = state.tc_left_rem and mp.get_property_number("playtime-remaining", 0) or mp.get_property_number("playback-time", 0)

    local function time_fmt(s)
        local has_h = (s >= 3600) or user_opts.time_format == "fixed"
        local base
        if has_h then
            -- hours shown as "8" or "88" depending on whether they reach 2 digits
            base = (s >= 36000 and "88" or "8") .. ":88:88"
        else
            -- minutes shown as "8" or "88" depending on whether they reach 2 digits
            base = (s >= 600 and "88" or "8") .. ":88"
        end
        return base .. (state.tc_ms and ".888" or "")
    end

    local prefix = state.tc_left_rem and (user_opts.unicodeminus and UNICODE_MINUS or "-") or ""
    local w = estimate_text_width(prefix .. time_fmt(rt_sec) .. " / " .. time_fmt(dur), get_osc_styles().time)
    return w ~= 0 and w or 120 + (state.tc_ms and 40 or 0)
end

local function get_touchtimeout()
    if state.touchtime == nil then
        return 0
    end
    return state.touchtime + (get_hidetimeout() / 1000) - mp.get_time()
end

local function cache_enabled()
    -- demuxer-cache-state can arrive as an empty table (no demuxer cache yet),
    -- so guard both the table and the "seekable-ranges" key before taking its length.
    local dcs = state.demuxer_cache_state
    return dcs and dcs["seekable-ranges"] and #dcs["seekable-ranges"] > 0
end

local function render_wipe(osd)
    msg.trace("render_wipe()")
    osd.data = "" -- allows set_osd to immediately update on enable
    osd:remove()
end

local function set_volume(slider_pos)
    local volume = slider_pos
    if user_opts.volume_control_type == "logarithmic" then
        volume = slider_pos^2 / 100
    end
    return math.floor(volume)
end

-- WindowControl helpers
local function window_controls_enabled()
    local val = user_opts.window_top_bar
    if val == "auto" then
        return not state.border or not state.title_bar or (state.fullscreen and platform ~= "darwin")
    else
        return val ~= "no"
    end
end

local function format_time(seconds)
    if not seconds then return "--:--" end

    local hours   = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs    = math.floor(seconds % 60)
    local show_hours = hours > 0 or user_opts.time_format == "fixed"

    if state.tc_ms then
        local ms = math.floor((seconds % 1) * 1000)
        if show_hours then
            return string.format("%d:%02d:%02d.%03d", hours, minutes, secs, ms)
        else
            return string.format("%d:%02d.%03d", minutes, secs, ms)
        end
    else
        if show_hours then
            return string.format("%d:%02d:%02d", hours, minutes, secs)
        else
            return string.format("%d:%02d", minutes, secs)
        end
    end
end

local function build_cache_seek_ranges()
    if not user_opts.seekrange or not cache_enabled() then return nil end
    if not state.duration then return nil end
    local nranges = {}
    for _, range in ipairs(state.demuxer_cache_state["seekable-ranges"]) do
        nranges[#nranges + 1] = {
            ["start"] = 100 * range["start"] / state.duration,
            ["end"]   = 100 * range["end"]   / state.duration,
        }
    end
    return nranges
end

-- Clear the private text width cache (called by osc_init on reinit)
local function clear_text_width_cache()
    for k in pairs(text_width_cache) do text_width_cache[k] = nil end
end

return {
    kill_animation = kill_animation,
    set_osd = set_osd,
    observe_cached = observe_cached,
    estimate_text_width = estimate_text_width,
    get_time_codes_width = get_time_codes_width,
    get_touchtimeout = get_touchtimeout,
    cache_enabled = cache_enabled,
    render_wipe = render_wipe,
    set_volume = set_volume,
    window_controls_enabled = window_controls_enabled,
    format_time = format_time,
    build_cache_seek_ranges = build_cache_seek_ranges,
    clear_text_width_cache = clear_text_width_cache,
}