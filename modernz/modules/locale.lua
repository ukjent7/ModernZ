-- modernz :: modules/locale.lua
-- Locale strings are module-owned data, accessed via get_locale() rather than a shared table.

local utils = require "mp.utils"

local user_opts = require("modules.options")

local language = {
    ["default"] = {
        idle = "Drop files or URLs here to play",
        na = "Not available",
        unknown = "Unknown",
        video = "Video",
        audio = "Audio",
        subtitle = "Subtitle",
        no_subs = "No subtitles",
        no_audio = "No audio tracks",
        volume = "Volume",
        muted = "Muted",
        playlist = "Playlist",
        no_playlist = "Playlist empty",
        chapter = "Chapter",
        fullscreen = "Fullscreen",
        fullscreen_exit = "Exit fullscreen",
        ontop = "Pin window",
        ontop_disable = "Unpin window",
        file_loop_enable = "Loop file on",
        file_loop_disable = "Loop file off",
        playlist_loop_enable = "Loop playlist on",
        playlist_loop_disable = "Loop playlist off",
        shuffle = "Shuffle playlist on",
        unshuffle = "Shuffle playlist off",
        speed_control = "Playback speed",
        screenshot = "Screenshot",
        stats_info = "Statistics",
        cache = "Cache",
        buffering = "Buffering",
        zoom_in = "Zoom in",
        zoom_out = "Zoom out",
        download = "Download",
        download_in_progress = "Download in progress",
        downloading = "Downloading",
        downloaded = "Already downloaded",
        menu = "Menu",
    },
}

local bidi = {
    fsi = "\226\129\168",   -- U+2068 first strong isolate
    pdi = "\226\129\169",   -- U+2069 pop directional isolate
}

-- Private locale table, populated by set_osc_locale()
local locale = {}

-- locale JSON file handler
local function get_locale_from_json(path)
    local expand_path = mp.command_native({'expand-path', path})

    local file_info = utils.file_info(expand_path)
    if not file_info or not file_info.is_file then
        return nil
    end

    local json_file = io.open(expand_path, 'r')
    if not json_file then
        return nil
    end

    local json = json_file:read('*all')
    json_file:close()

    local json_table, parse_error = utils.parse_json(json)
    if not json_table then
        mp.msg.error("JSON parse error:" .. parse_error)
    end
    return json_table
end


local locale_file_loaded = false
local function load_locale_file()
    if user_opts.language == "default" or locale_file_loaded then return end
    locale_file_loaded = true

    local external = get_locale_from_json("~~/script-opts/modernz-locale.json")
    if external then
        for lang, strings in pairs(external) do
            if lang == "default" then
                -- "default" is reserved
                mp.msg.warn("Locale JSON: 'default' is a reserved language key and cannot be overridden. Skipping.")
            elseif type(strings) == "table" then
                language[lang] = strings

                -- fill in any missing keys with the built-in defaults
                for key, value in pairs(language["default"]) do
                    if strings[key] == nil then
                        strings[key] = value
                    end
                end
            else
                mp.msg.warn("Locale data for language '" .. lang .. "' is not in the correct format.")
            end
        end
    end
end

local function set_osc_locale()
    local _loc = language[user_opts.language] or language["default"]
    for k in pairs(locale) do locale[k] = nil end
    if _loc then for k, v in pairs(_loc) do locale[k] = v end end
end

-- Accessor: returns the private locale table (read-only by convention).
local function get_locale()
    return locale
end

return {
    language = language,
    bidi = bidi,
    get_locale = get_locale,
    get_locale_from_json = get_locale_from_json,
    load_locale_file = load_locale_file,
    set_osc_locale = set_osc_locale,
}