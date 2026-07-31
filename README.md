# ModernZ — A Sleek Alternative OSC for mpv

**[English](README.md)** · [简体中文](README_zh.md)

A sleek and modern OSC (On Screen Controller) for [mpv](https://mpv.io/). This project is a fork of ModernX that enhances functionality with more features while preserving the core standards of mpv's OSC.

This distribution ships the **modular refactor** of ModernZ (v0.3.3): the former single-file `main.lua` is split into small `modules/*.lua` files with clear responsibilities (layouts, rendering, events, options, styles, icons, locale, margins, …), bundled together with a **portable mpv build for Windows**.

![modernz_preview](https://github.com/user-attachments/assets/69a967ae-cf8a-4a92-9193-4799f901cd94)

<p align="center">
  <a href="#installation"><strong>Installation »</strong></a><br>
  <a href="#configuration">Configuration</a> ·
  <a href="#controls">Controls</a> ·
  <a href="#translations">OSC Language</a> ·
  <a href="#troubleshooting">Troubleshooting</a>
</p>

## Features

- 🎨 Modern, customizable interface with multiple layouts, themes, and icon styles [[options](#customization)]
- 🖱️ Independent hover zones for the top bar (window controls) and the bottom bar (OSC)
- 🖼️ Image Viewer mode with zoom controls
- 🎛️ Buttons: download, playlist, speed control, screenshot, pin, loop, shuffle, and more
- 📄 Interactive menus for playlist, subtitles, chapters, audio tracks, and audio devices
- 🌐 Multi-language support with JSON [locale](#translations) integration
- ⌨️ Configurable controls [[details](#controls)]
- 🖼️ Video thumbnail previews with [thumbfast](https://github.com/po5/thumbfast)
- ⚙️ **The stock OSC is disabled automatically** — no manual `osc=no` is required in `mpv.conf`

## Customization

ModernZ provides a wide range of customization options, including multiple layouts, themes, icon styles, color adjustments, and much more. All options live in `script-opts/modernz.conf` (defaults are included — change only what you need and restart mpv).

### Layouts

Choose the layout that suits your preference with the `layout` option: `default`, `compact`, `mini`, or `seekbar`.

<table>
    <thead>
        <tr><th><code>default</code></th></tr>
    </thead>
    <tbody>
        <tr><td><img width="1961" height="125" alt="layout_default" src="https://github.com/user-attachments/assets/afa29219-d3ea-490b-bf34-530a9ba212a4" /></td></tr>
    </tbody>
</table>
<table>
    <thead>
        <tr><th><code>compact</code></th></tr>
    </thead>
    <tbody>
        <tr><td><img width="1961" height="125" alt="layout_compact" src="https://github.com/user-attachments/assets/6a51fd86-5ed0-4162-9991-8edad2250221" /></td></tr>
    </tbody>
</table>
<table>
    <thead>
        <tr><th><code>mini</code></th></tr>
    </thead>
    <tbody>
        <tr><td><img width="1961" height="125" alt="layout_mini" src="https://github.com/user-attachments/assets/a4f5d467-0286-4280-b284-9aaec8e6e42f" /></td></tr>
    </tbody>
</table>
<table>
    <thead>
        <tr><th><code>seekbar</code></th></tr>
    </thead>
    <tbody>
        <tr><td><img width="1961" height="124" alt="layout_seekbar" src="https://github.com/user-attachments/assets/4479b9d3-cdfb-4ebb-ac85-8d4c8ba101e1" /></td></tr>
    </tbody>
</table>

### Icon Themes & Styles

Switch the icon theme with `icon_theme` (`fluent` or `material`) and the style with `icon_style` (`mixed`, `filled`, or `outline`).

<table>
    <thead><tr><th colspan="2"><code>fluent</code></th></tr></thead>
    <tbody>
        <tr><td><code>mixed</code></td><td><img width="1961" height="125" alt="fluent_mixed" src="https://github.com/user-attachments/assets/ce59d30d-adcf-4961-b153-4711a7bc12c6" /></td></tr>
        <tr><td><code>filled</code></td><td><img width="1961" height="125" alt="fluent_filled" src="https://github.com/user-attachments/assets/a5047c68-c8be-43c9-9c5a-c12dbeeb916f" /></td></tr>
        <tr><td><code>outline</code></td><td><img width="1961" height="125" alt="fluent_outline" src="https://github.com/user-attachments/assets/ce660cf4-b3f9-43a1-af92-fe2175a43bf6" /></td></tr>
    </tbody>
</table>

<table>
    <thead><tr><th colspan="2"><code>material</code></th></tr></thead>
    <tbody>
        <tr><td><code>mixed</code></td><td><img width="1961" height="125" alt="material_mixed" src="https://github.com/user-attachments/assets/3fb6730b-3ec2-4ce2-80e8-41faf2aced8c" /></td></tr>
        <tr><td><code>filled</code></td><td><img width="1961" height="125" alt="material_filled" src="https://github.com/user-attachments/assets/befe569c-ea72-42b4-a0f0-f189578a0df5" /></td></tr>
        <tr><td><code>outline</code></td><td><img width="1961" height="125" alt="material_outline" src="https://github.com/user-attachments/assets/8f28b937-d03c-4920-98c4-b69998989626" /></td></tr>
    </tbody>
</table>

> Preview images above are hosted on the [upstream ModernZ repository](https://github.com/Samillion/ModernZ).

### Seek Bar & Chapter Markers

- `seekbar_height` — `small`, `medium` (default), `large`, `xlarge`
- `nibbles_style` — chapter markers as `gap` (default), `triangle`, `bar`, or `single-bar`

### Colors

Not a fan of white buttons and text? You have complete control to customize colors. The most commonly used ones:

```EditorConfig
# Accent / seekbar
osc_color=#000000
seekbarfg_color=#FF8232
seekbarbg_color=#999999
seek_handle_color=#C96508

# Text
title_color=#FFFFFF
time_color=#FFFFFF
side_buttons_color=#FFFFFF
middle_buttons_color=#FFFFFF
playpause_color=#FFFFFF
chapter_title_color=#FFFFFF

# Hover / accents
hover_effect_color=#FF8232
held_element_color=#999999
nibble_color=#FF8232
nibble_current_color=#FFFFFF
```

For the full list of options, see the [upstream ModernZ user-options guide](https://github.com/Samillion/ModernZ/blob/main/docs/USER_OPTS.md).

## Installation

> **Requirements:** mpv **≥ 0.35** (text measurement uses `osd_overlay.compute_bounds`; on older versions the OSC degrades gracefully). [thumbfast](https://github.com/po5/thumbfast) is required for thumbnail previews; [yt-dlp](https://github.com/yt-dlp/yt-dlp) + ffmpeg are required for the download button.

This folder **is** the player. Everything is self-contained:

1. **Run it.** Double-click `mpv.exe` (or use the included `mpv-register.bat` to associate file types with mpv; `mpv-unregister.bat` removes the associations).
2. **Nothing to disable.** The stock OSC is turned off automatically by `scripts/main.lua` once it finishes loading. Do **not** add `osc=no` to `mpv.conf`.
3. **Optional native title bar.** `portable_config/mpv.conf` already sets `title-bar=no` so ModernZ's drawn window controls (close/minimize/maximize) replace the native one. Remove that line if you prefer the native bar.

### Folder Structure

```
📁 mpv-v0.41.0/
├── 📄 mpv.exe / mpv.com / vulkan-1.dll   ← the player
├── 📄 mpv-register.bat / mpv-unregister.bat
└── 📁 portable_config/                    ← mpv config dir (portable mode)
    ├── 📁 fonts/
    │   └── 📄 modernz-icons.ttf
    ├── 📁 script-opts/
    │   ├── 📄 modernz.conf             ← ModernZ options (all defaults)
    │   ├── 📄 modernz-locale.json      ← UI translations
    │   └── 📄 thumbfast.conf
    ├── 📁 scripts/
    │   ├── 📄 main.lua                 ← ModernZ entry point (auto-loaded)
    │   └── 📁 modules/                 ← required by main.lua, not auto-loaded
    │       ├── 📄 core.lua, options.lua, events.lua, layouts.lua,
    │       ├── 📄 rendering.lua, osc_init.lua, margin_utils.lua,
    │       └── 📄 (…)
    ├── 📄 thumbfast.lua                ← thumbnail previews
    ├── 📄 acompressor.lua              ← audio compressor filter control
    ├── 📄 mpv.conf
    ├── 📄 input.conf
    └── 📁 watch_later/
```

> **How scripts load:** mpv auto-loads `scripts/*.lua`, and also `.lua` files placed directly in the config dir root (`thumbfast.lua`, `acompressor.lua`). `main.lua` resolves the `modules/` folder relative to its own path, so `modules/` must stay next to it. The modules are only `require`d by `main.lua` — they are not auto-loaded and must not be moved.

> **Non-portable setups:** to use this with a regular mpv install, copy `scripts/`, `fonts/`, and `script-opts/` into your mpv config dir
> (`~/.config/mpv/`, `C:/Users/%username%/AppData/Roaming/mpv/`, or `~/Library/Application Support/mpv/`).

## Configuration

- All options live in `script-opts/modernz.conf` — it ships with every default, so you can also just keep the lines you change.
- Edit the file and restart mpv (or use the `script-opts` config-reload if you bind it).

A quick reference of the most useful options:

| Option | What it does | Default |
| --- | --- | --- |
| `language` | UI language (`default`, `zh`, `en`, …) | `default` |
| `layout` | `default` / `compact` / `mini` / `seekbar` | `default` |
| `icon_theme` | `fluent` / `material` | `fluent` |
| `icon_style` | `mixed` / `filled` / `outline` | `mixed` |
| `hidetimeout` | ms before the OSC auto-hides | `1500` |
| `fadeduration` | fade in/out duration in ms (0 = none) | `200` |
| `deadzonesize` | deadzone size (0.0 = show anywhere, 1.0 = hover only) | `0.75` |
| `visibility` | `auto` / `always` / `never` | `auto` |
| `osc_on_start` | show OSC on file start (`no`/`bottom`/`top`/`both`) | `both` |
| `showonpause` | show OSC while paused | `yes` |
| `keeponpause` | keep OSC while paused (`no`/`bottombar`/`both`) | `no` |
| `sub_margins` | raise subtitles above the OSC when it is shown | `yes` |
| `dynamic_margins` | apply margins dynamically with OSC visibility | `yes` |
| `osd_margins` | also shift the OSD text to avoid the OSC | `no` |
| `persistent_progress` | always show a thin progress line at the bottom | `no` |
| `seekbar_height` | `small` / `medium` / `large` / `xlarge` | `medium` |
| `nibbles_style` | chapter markers `gap`/`triangle`/`bar`/`single-bar` | `gap` |
| `download_path` | where the download button saves files | `~~desktop/mpv` |
| `visibility_modes` | modes cycled by the visibility binding | `never_auto_always` |

## Controls

### Button Interactions

- Left click: primary action
- Right click: secondary action
- Middle click / `Shift+Left click`: alternative action

> Middle clicking performs the same function as `Shift+left mouse button`, allowing one-handed use.

Every mouse action is remappable via `modernz.conf` — e.g. `title_mbtn_left_command`, `seekbar_wheel_up_command`, `playlist_mbtn_right_command`, etc.

### Keybinds

ModernZ does **not** bind keys by default to avoid interfering with your setup. You can add bindings in `input.conf`:

```
v   script-binding modernz/visibility              # Cycle visibility modes
V   script-message-to modernz osc-visibility cycle # Set visibility: cycle, auto, always, never
w   script-binding modernz/progress-toggle         # Toggle persistent progress
x   script-message-to modernz osc-show             # Show OSC
y   script-message-to modernz osc-hide             # Hide OSC
z   script-message-to modernz osc-idlescreen       # Toggle idle screen
```

The bundled `portable_config/input.conf` already configures a few playback bindings:
`z`/`x` adjust subtitle delay, `[`/`]` change speed, `LEFT`/`RIGHT` seek, and the left mouse button toggles play/pause.

## Translations

The UI language is controlled by the `language` option in `modernz.conf` — this package sets it to Simplified Chinese (`language=zh`). Available languages: `ar`, `de`, `dk`, `en`, `es`, `fr`, `is`, `jp`, `pl`, `ru`, `zh`.

To contribute or add a new language, see the [upstream translation guide](https://github.com/Samillion/ModernZ/blob/main/docs/TRANSLATIONS.md).

## Extras

The package bundles two extra scripts (also placed in the config root):

- [thumbfast](https://github.com/po5/thumbfast) — frame-accurate thumbnail previews on the seekbar (`script-opts/thumbfast.conf` configures it).
- `acompressor.lua` — on-screen control for the ffmpeg dynamic-range compressor filter. Toggle with `n`, adjust threshold with `F1`/`Shift+F1` and ratio with `F2`/`Shift+F2`.

The download button requires [yt-dlp](https://github.com/yt-dlp/yt-dlp) and ffmpeg on `PATH`.

## Troubleshooting

### Subtitles are pushed up and don't drop back down

ModernZ's `sub_margins` feature raises subtitles by temporarily lowering `sub-pos` while the OSC is visible. On mpv **0.36+** the default `watch-later-options` includes `sub-pos`, so with position saving enabled (`save-position-on-quit=yes`) the *raised* value gets written to `watch_later/`. On the next play, mpv restores that raised `sub-pos`, ModernZ mistakes it for your real position, and the subtitle stays suspended above the bottom of the screen.

**Fix (already applied in this package):**

```ini
# portable_config/mpv.conf
watch-later-options-remove=sub-pos
```

This removes `sub-pos` from what mpv saves/restores, so the temporary raise is never persisted. If you already have stale `watch_later/*` files containing a `sub-pos=` line, delete that line (or the file) once. If you use `osd_margins=yes` as well, add `watch-later-options-remove=osd-margin-y` too.

## History

- [Samillion/ModernZ](https://github.com/Samillion/ModernZ)
  - forked from [dexeonify/ModernX](https://github.com/dexeonify/mpv-config/blob/main/scripts/modernx.lua)
    - forked from [cyl0/ModernX](https://github.com/cyl0/ModernX)
      - forked from [maoiscat/mpv-osc-modern](https://github.com/maoiscat/mpv-osc-modern)

**Why fork yet again?**

- Add extensive feature support, including color customization, advanced options, and locale integration
- Integrate mpv's `console` and `select` functionality into the OSC
- Introduce a layout optimized for image viewing
- Add `fluent`/`material` icon themes and `mixed`/`filled`/`outline` styles
- **Refactor the project to align with mpv's stock OSC standards**, ensuring long-term compatibility
- Remove legacy bugs and redundant code to improve maintainability and stability
  - This enables other `Modern` forks to build on ModernZ as a foundation

In essence, to maintain and revive the `modern-osc` origin. ModernZ still uses parts of the old code, and every previous and current fork author and contributor deserves credit (including mpv's stock osc).

#### Credits:

- [Material Symbols](https://github.com/google/material-design-icons) by Google — [Apache 2.0](https://github.com/google/material-design-icons?tab=Apache-2.0-1-ov-file#readme)
- [Fluent System Icons](https://github.com/microsoft/fluentui-system-icons) by Microsoft — [MIT](https://github.com/microsoft/fluentui-system-icons?tab=MIT-1-ov-file#readme)
- [mpv](https://github.com/mpv-player/mpv) and their [osc.lua](https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua), as ModernZ's OSC was re-based on the stock OSC standards
- All modern-osc originators and their forks as mentioned in [history](#history)
- All contributors, testers, and users ❤️

## HH-AA

<table>
  <tr>
    <td>
      - In quiet memory, always.<br>
      - Somewhere beyond time, we'll meet again.
  </td>
  </tr>
  <tr>
    <td>
      <img width="973" height="309" alt="c7dbd158" src="https://github.com/user-attachments/assets/416388f1-6b3f-4e9f-8be4-2364f8aa0c96" />
    </td>
  </tr>
</table>
