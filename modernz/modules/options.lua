-- modernz :: modules/options.lua
-- Default user option values.
-- Do not change here; override them in modernz.conf.

local _constants = require("modules.constants")
local COLOR_DEFAULTS = _constants.COLOR_DEFAULTS

local user_opts = {
    -- Language and display
    language = "default",                  -- set language
    layout = "default",                    -- set layout: default, compact, mini, seekbar
    icon_theme = "fluent",                 -- set icon theme. accepts "fluent" or "material"
    icon_style = "mixed",                  -- "mixed", "filled", "outline"
    font = "mpv-osd-symbols",              -- font for the OSC (default: mpv-osd-symbols or the one set in mpv.conf)

    idlescreen = true,                     -- show mpv logo when idle
    window_top_bar = "auto",               -- show OSC window top bar: "auto", "yes", or "no" (borderless/fullscreen)
    showwindowed = true,                   -- show OSC when windowed
    showfullscreen = true,                 -- show OSC when fullscreen
    showonselect = false,                  -- show OSC when a select menu is open
    showonpause = true,                    -- show OSC when paused
    keeponpause = "no",                    -- keep OSC visible while paused: "no", "bottombar", "both"
    greenandgrumpy = false,                -- disable Santa hat in December

    -- OSC behaviour and scaling
    hidetimeout = 1500,                    -- time (in ms) before OSC hides if no mouse movement
    keep_with_cursor = true,               -- keep OSC visible while cursor hovers over bottom or top bar
    fadeduration = 200,                    -- fade-out duration (in ms), set to 0 for no fade
    fadein = true,                         -- whether to enable fade-in effect
    minmousemove = 0,                      -- minimum mouse movement (in pixels) required to show OSC
    deadzonesize = 0.75,                   -- size of the deadzone (0.0 = whole screen, 1.0 = no deadzone)
    deadzone_hide = "instant",             -- hide behavior when cursor enters deadzone or leaves window: "instant" or "timeout"
    osc_on_seek = true,                    -- show OSC when seeking
    osc_on_start = "both",                 -- show OSC on start of every file ("no", "bottom", "top", "both")
    mouse_seek_pause = true,               -- pause video while seeking with mouse move (on button hold)
    force_seek_tooltip = false,            -- force show seekbar tooltip on mouse drag, even if not hovering seekbar

    vidscale = "auto",                     -- scale osc with the video
    scalewindowed = 1.0,                   -- osc scale factor when windowed
    scalefullscreen = 1.0,                 -- osc scale factor when fullscreen

    -- Elements display
    show_title = true,                     -- show title in the OSC
    title = "${media-title}",              -- title: "${media-title}" or "${filename}"
    title_font_size = 24,                  -- title font size
    truncate_title = false,                -- truncate title with ellipsis if it overflows
    chapter_title_font_size = 16,          -- chapter title font size

    cache_info = false,                    -- show cached time information
    cache_info_speed = false,              -- show cache speed per second
    cache_info_font_size = 12,             -- font size of the cache information

    show_chapter_title = true,             -- show chapter title
    chapter_above_title = false,           -- show chapter above title
    chapter_fmt = "%s",                    -- format for chapter display on seekbar hover (set to "no" to disable)

    timecurrent = true,                    -- show current time instead of remaining time
    timems = false,                        -- show timecodes with milliseconds
    unicodeminus = false,                  -- use the Unicode minus sign in remaining time
    time_format = "dynamic",               -- "dynamic" or "fixed". dynamic shows MM:SS when possible, fixed always shows HH:MM:SS
    time_font_size = 16,                   -- font size of the time display

    tooltip_font_size = 14,                -- tooltips font size
    speed_font_size = 16,                  -- speed button font size

    -- Title bar settings
    show_window_title = false,             -- show window title in borderless/fullscreen mode
    window_title_font_size = 26,           -- window title font size
    window_controls = true,                -- show window controls (close, minimize, maximize) in borderless/fullscreen
    windowcontrols_independent = true,     -- show window controls (top bar) and bottom bar independently on hover

    -- Subtitle and OSD display settings
    sub_margins = true,                    -- raise subtitles above the OSC when shown
    osd_margins = false,                   -- adjust OSD to not overlap with OSC
    dynamic_margins = true,                -- update margins dynamically with OSC visibility

    -- Buttons display and functionality
    subtitles_button = true,               -- show the subtitles menu button
    audio_tracks_button = true,            -- show the audio tracks menu button
    jump_buttons = true,                   -- show the jump backward and forward buttons
    jump_amount = 10,                      -- change the jump amount in seconds
    jump_more_amount = 60,                 -- change the jump amount in seconds on right click
    jump_icon_number = true,               -- show different icon when jump_amount is set to 5, 10, or 30
    jump_mode = "relative",                -- seek mode for jump buttons: "relative" or "exact"
    jump_softrepeat = true,                -- enable continuous jumping when holding down seek buttons
    chapter_skip_buttons = false,          -- show the chapter skip backward and forward buttons
    track_nextprev_buttons = true,         -- show next/previous playlist track buttons

    volume_control = true,                 -- show mute button and volume slider
    volume_control_type = "linear",        -- volume scale type: "linear" or "logarithmic"
    volumebar_unmute_on_click = false,     -- unmute audio when adjusting volume slider with left click
    playlist_button = true,                -- show playlist button
    hide_empty_playlist_button = false,    -- hide playlist button when no playlist exists
    gray_empty_playlist_button = false,    -- gray out the playlist button when no playlist exists

    fullscreen_button = true,              -- show fullscreen toggle button
    info_button = true,                    -- show info button
    ontop_button = true,                   -- show window on top button
    ontop_in_topbar = false,               -- move ontop button to top bar when ontop is active
    screenshot_button = true,              -- show screenshot button

    download_button = true,                -- show download button on web videos (requires yt-dlp and ffmpeg)
    download_path = "~~desktop/mpv",       -- default download directory for videos (https://mpv.io/manual/master/#paths)

    loop_button = true,                    -- show file loop button
    shuffle_button = false,                -- show shuffle button
    speed_button = true,                   -- show speed control button
    speed_presets = "0.5,0.75,1.0,1.25,1.5,2.0,3.0", -- speed preset values for the speed menu

    buttons_always_active = "none",        -- force buttons to always be active. can add: playlist_prev, playlist_next

    playpause_size = 28,                   -- icon size for the play/pause button
    midbuttons_size = 24,                  -- icon size for the middle buttons
    sidebuttons_size = 24,                 -- icon size for the side buttons

    zoom_control = true,                   -- show zoom controls in image viewer mode
    zoom_in_max = 4,                       -- maximum zoom in value
    zoom_out_min = -1,                     -- minimum zoom out value

    -- Colors and style
    -- Color defaults are defined in constants.COLOR_DEFAULTS and copied into
    -- user_opts at the end of this file (see the populate loop below).
    seek_handle_border_color = "#FF8232",  -- inner border color drawn inside the seekbar handle (set to "disable" to disable)
    volumebar_match_seek_color = false,    -- match volume bar color with seekbar color (ignores side_buttons_color)

    osc_fade_strength = 100,               -- strength of the OSC background fade (0 to disable)
    fade_blur_strength = 100,              -- blur strength for the OSC alpha fade. caution: high values can take a lot of CPU time to render
    fade_transparency_strength = 0,        -- use with "fade_blur_strength=0" to create a transparency box
    window_fade_strength = 100,            -- strength of the window title bar fade (0 to disable)
    window_fade_blur_strength = 100,       -- blur strength for the window title bar. caution: high values can take a lot of CPU time to render
    window_fade_transparency_strength = 0, -- use with "window_fade_blur_strength=0" to create a transparency box
    thumbnail_box_padding = 4.5,           -- thumbnail box padding around the image
    thumbnail_box_radius = 4,              -- round corner radius for thumbnail box border (0 to disable)
    thumbnail_box_outline_size = 1,        -- thumbnail box border outline size (thickness)

    -- Button interaction settings
    hover_effect = "size,glow,color,box",  -- active button hover effects: "glow", "size", "color", "box"; can use multiple separated by commas
    button_hover_size = 115,               -- relative size of a hovered button if "size" effect is active
    button_held_size = 100,                -- relative size of a button when held/pressed. below 100 shrinks button when held down
    button_held_box_alpha = 18,            -- alpha of the hover background box when a button is held down
    button_glow_amount = 5,                -- glow intensity when "glow" hover effect is active
    slider_hover_size = 100,               -- relative size of a hovered slider handle
    tooltip_hints = true,                  -- enable tooltips for most buttons. seek and volume tooltips are always enabled

    -- Progress bar settings
    seek_handle_size = 0.8,                -- size ratio of the seek handle (range: 0 ~ 1)
    seek_handle_border_size = 0.42,        -- border thickness as a fraction of the handle radius
    seek_handle_border_hover_size = 0.31,  -- border thickness when handle is hovered (set equal to seek_handle_border_size to disable)
    seekbar_height = "medium",             -- seekbar height preset: "small", "medium", "large", "xlarge"
    seekrange = true,                      -- show seek range overlay
    seekrangealpha = 150,                  -- transparency of the seek range
    livemarkers = true,                    -- update chapter markers on the seekbar when duration changes
    seekbarkeyframes = true,               -- use keyframes when dragging the seekbar
    slider_rounded_corners = true,         -- rounded corners seekbar slider

    nibbles_style = "gap",                 -- chapter nibble style: "gap", "triangle", "bar", or "single-bar"
    nibbles_top = true,                    -- top chapter nibbles above seekbar
    nibbles_bottom = true,                 -- bottom chapter nibbles below seekbar

    automatickeyframemode = true,          -- automatically set keyframes for the seekbar based on video length
    automatickeyframelimit = 600,          -- videos longer than this (in seconds) will have keyframes on the seekbar

    persistent_progress = false,           -- always show a small progress line at the bottom of the screen
    persistent_progress_height = 17,       -- height of the persistent progress bar
    persistent_buffer = false,             -- show cached buffer status in the persistent progress line

    -- Miscellaneous settings
    visibility = "auto",                   -- only used at init to set visibility_mode(...)
    visibility_modes = "never_auto_always",-- visibility modes to cycle through
    tick_delay = 1 / 60,                   -- minimum interval between OSC redraws (in seconds)
    tick_delay_follow_display_fps = false, -- use display FPS as the minimum redraw interval

    -- Elements Position
    -- Useful when adjusting font size or type
    title_offset = 20,                     -- title vertical offset relative to seekbar
    title_with_chapter_offset = 5,         -- title vertical offset if a chapter title is below it
    chapter_title_offset = 18,             -- chapter title vertical offset relative to seekbar
    chapter_above_title_offset = 3,        -- chapter offset when shown above title
    time_codes_offset = 0,                 -- time codes vertical offset relative to seekbar
    tooltip_height_offset = 5,             -- tooltip height position offset
    portrait_window_trigger = 950,         -- portrait window width trigger to move some elements
    hide_volume_bar_trigger = 1150,        -- hide volume bar trigger window width
    osc_height = 60,                       -- osc height

    -- Mouse commands
    -- customize the button function based on mouse action

    -- title mouse actions
    title_mbtn_left_command = "script-binding stats/display-page-5",
    title_mbtn_mid_command = "show-text ${path}",
    title_mbtn_right_command = "script-binding select/select-watch-history",

    -- chapter title mouse actions
    chapter_title_mbtn_left_command = "script-binding select/select-chapter",
    chapter_title_mbtn_right_command = "show-text ${chapter-list} 3000",

    -- seekbar wheel actions
    seekbar_wheel_up_command = "seek 10",
    seekbar_wheel_down_command = "seek -10",

    -- playlist button mouse actions
    playlist_mbtn_left_command = "script-binding select/select-playlist",
    playlist_mbtn_right_command = "script-binding select/menu",

    -- volume mouse actions
    vol_ctrl_mbtn_left_command = "no-osd cycle mute",
    vol_ctrl_mbtn_right_command = "script-binding select/select-audio-device",
    vol_ctrl_wheel_down_command = "osd-msg add volume -5",
    vol_ctrl_wheel_up_command = "osd-msg add volume 5",
    volumebar_wheel_down_command = "osd-msg add volume -5",
    volumebar_wheel_up_command = "osd-msg add volume 5",

    -- audio button mouse actions
    audio_track_mbtn_left_command = "script-binding select/select-aid",
    audio_track_mbtn_mid_command = "cycle audio down",
    audio_track_mbtn_right_command = "cycle audio",
    audio_track_wheel_down_command = "cycle audio",
    audio_track_wheel_up_command = "cycle audio down",

    -- subtitle button mouse actions
    sub_track_mbtn_left_command = "script-binding select/select-sid",
    sub_track_mbtn_mid_command = "cycle sub down",
    sub_track_mbtn_right_command = "cycle sub",
    sub_track_wheel_down_command = "cycle sub",
    sub_track_wheel_up_command = "cycle sub down",

    -- play/pause button mouse actions
    play_pause_mbtn_left_command = "cycle pause",
    play_pause_mbtn_mid_command = "cycle-values loop-playlist inf no",
    play_pause_mbtn_right_command = "cycle-values loop-file inf no",

    -- chapter skip buttons mouse actions
    chapter_prev_mbtn_left_command = "add chapter -1",
    chapter_prev_mbtn_mid_command = "show-text ${chapter-list} 3000",
    chapter_prev_mbtn_right_command = "script-binding select/select-chapter",

    chapter_next_mbtn_left_command = "add chapter 1",
    chapter_next_mbtn_mid_command = "show-text ${chapter-list} 3000",
    chapter_next_mbtn_right_command = "script-binding select/select-chapter",

    -- playlist skip buttons mouse actions
    playlist_prev_mbtn_left_command = "playlist-prev",
    playlist_prev_mbtn_mid_command = "show-text ${playlist} 3000",
    playlist_prev_mbtn_right_command = "script-binding select/select-playlist",

    playlist_next_mbtn_left_command = "playlist-next",
    playlist_next_mbtn_mid_command = "show-text ${playlist} 3000",
    playlist_next_mbtn_right_command = "script-binding select/select-playlist",

    -- fullscreen button mouse actions
    fullscreen_mbtn_left_command = "cycle fullscreen",
    fullscreen_mbtn_right_command = "cycle window-maximized",

    -- info button mouse actions
    info_mbtn_left_command = "script-binding stats/display-page-1-toggle",

    -- ontop (pin) button mouse actions
    ontop_mbtn_left_command = "osd-msg cycle ontop",

    -- screenshot button mouse actions
    screenshot_mbtn_left_command = "osd-msg screenshot video",

    -- loop file button mouse actions
    file_loop_mbtn_left_command = "osd-msg cycle-values loop-file inf no",
    file_loop_mbtn_right_command = "osd-msg cycle-values loop-playlist inf no",

    -- speed button mouse actions
    speed_mbtn_left_command = "osd-msg add speed 1",
    speed_mbtn_right_command = "osd-msg set speed 1",
    speed_wheel_down_command = "osd-msg add speed -0.25",
    speed_wheel_up_command = "osd-msg add speed 0.25",
}

-- Copy color defaults from constants so user_opts stays an independent,
-- user-overridable table (a shared reference would let validation writes
-- leak into the constants table).
for k, v in pairs(COLOR_DEFAULTS) do user_opts[k] = v end

return user_opts
