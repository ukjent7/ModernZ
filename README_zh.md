# ModernZ —— 为 mpv 打造的精美替代 OSC

[English](README.md) · **[简体中文](README_zh.md)**

一款为 [mpv](https://mpv.io/) 设计的现代、精美的 OSC（屏幕显示控制条）。本项目是 ModernX 的分支，在保留 mpv 官方 OSC 核心规范的基础上加入了更多功能。

本仓库维护的是 **ModernZ（v0.3.3）的模块化重构版本**：原先单文件的 `main.lua` 被拆分成了职责清晰的 `modules/*.lua`（布局、渲染、事件、选项、样式、图标、语言、边距等模块），全部由 `main.lua` 通过 `require` 引入。

![modernz_preview](https://github.com/user-attachments/assets/69a967ae-cf8a-4a92-9193-4799f901cd94)

<p align="center">
  <a href="#安装"><strong>安装 »</strong></a><br>
  <a href="#配置">配置</a> ·
  <a href="#操作">操作</a> ·
  <a href="#界面语言">界面语言</a> ·
  <a href="#常见问题">常见问题</a>
</p>

## 功能特性

- 🎨 现代化、可高度自定义的界面：多种布局、主题与图标样式 [[选项](#自定义)]
- 🖱️ 顶栏（窗口控制条）与底栏（OSC）拥有各自独立的悬停触发区域
- 🖼️ 图片查看模式，支持缩放控制
- 🎛️ 丰富的按钮：下载、播放列表、倍速、截图、置顶、循环、随机播放等
- 📄 播放列表、字幕、章节、音轨、音频设备的交互式菜单
- 🌐 多语言支持，基于 JSON [locale](#界面语言)
- ⌨️ 可自定义的按键与鼠标操作 [[详情](#操作)]
- 🖼️ 基于 [thumbfast](https://github.com/po5/thumbfast) 的进度条缩略图预览
- ⚙️ **自动禁用官方 OSC** —— 无需手动在 `mpv.conf` 里写 `osc=no`

## 自定义

ModernZ 提供了大量自定义选项，包括多种布局、主题、图标样式、颜色调整等等。所有选项都位于 `script-opts/modernz.conf`（已包含全部默认值，只需修改你需要的内容并重启 mpv）。

### 布局

通过 `layout` 选项选择布局：`default`、`compact`、`mini` 或 `seekbar`。

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

### 图标主题与样式

用 `icon_theme` 切换图标主题（`fluent` 或 `material`），用 `icon_style` 切换样式（`mixed`、`filled` 或 `outline`）。

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

> 以上预览图来自[上游 ModernZ 仓库](https://github.com/Samillion/ModernZ)。

### 进度条与章节标记

- `seekbar_height` —— `small`、`medium`（默认）、`large`、`xlarge`
- `nibbles_style` —— 章节标记样式：`gap`（默认）、`triangle`、`bar` 或 `single-bar`

### 颜色

不喜欢白色的按钮和文字？你可以完全自定义颜色。最常用的几个：

```EditorConfig
# 强调色 / 进度条
osc_color=#000000
seekbarfg_color=#FF8232
seekbarbg_color=#999999
seek_handle_color=#C96508

# 文字
title_color=#FFFFFF
time_color=#FFFFFF
side_buttons_color=#FFFFFF
middle_buttons_color=#FFFFFF
playpause_color=#FFFFFF
chapter_title_color=#FFFFFF

# 悬停 / 强调
hover_effect_color=#FF8232
held_element_color=#999999
nibble_color=#FF8232
nibble_current_color=#FFFFFF
```

完整的选项列表请参见[上游 ModernZ 用户选项指南](https://github.com/Samillion/ModernZ/blob/main/docs/USER_OPTS.md)。

## 安装

> **环境要求：** mpv **≥ 0.35**（文本测量使用 `osd_overlay.compute_bounds`；旧版本会优雅降级）。缩略图预览需要 [thumbfast](https://github.com/po5/thumbfast)；下载按钮需要 [yt-dlp](https://github.com/yt-dlp/yt-dlp) 与 ffmpeg。

1. **复制脚本** —— 将 `scripts/main.lua` 连同它的 `scripts/modules/` 文件夹一起放入 mpv 的 `scripts` 目录。mpv 会自动加载 `main.lua`；`modules/` 里的文件只被它 `require`。
2. **安装图标** —— 将 `fonts/modernz-icons.ttf` 复制到 mpv 的 `fonts` 目录。
3. **配置** —— 将 `script-opts/modernz.conf` 复制到 mpv 的 `script-opts` 目录（按需修改）。
4. **可选附件** —— `modernz-locale.json` 放到 `script-opts/`，`thumbfast.lua` 放到 `scripts/`，`thumbfast.conf` 放到 `script-opts/`。
5. **无需手动禁用官方 OSC。** `main.lua` 加载完成后会自动关闭官方 OSC，**不要**在 `mpv.conf` 里再写 `osc=no`。

### 目录结构

```
📁 mpv/                              ← 你的 mpv 配置目录
├── 📁 fonts/
│   └── 📄 modernz-icons.ttf
├── 📁 script-opts/
│   ├── 📄 modernz.conf              ← 全部 ModernZ 选项（含默认值）
│   └── 📄 modernz-locale.json       ← 界面翻译（可选）
└── 📁 scripts/
    ├── 📄 main.lua                  ← 入口（自动加载）
    └── 📁 modules/                  ← 仅被 main.lua require，不会被自动加载
        ├── 📄 core.lua, options.lua, events.lua, layouts.lua,
        ├── 📄 rendering.lua, osc_init.lua, margin_utils.lua,
        └── 📄 (…)
```

常见配置目录：Linux：`~/.config/mpv/`，Windows：`C:/Users/%username%/AppData/Roaming/mpv/`，macOS：`~/Library/Application Support/mpv/`。

> **脚本加载方式：** mpv 会自动加载 `scripts/*.lua` 以及 `scripts/<子目录>/main.lua`。`modules/` 子目录里没有 `main.lua`，因此其中的文件只被 `main.lua` 引用，必须与它放在一起。启动时 mpv 会打印一条无害的 `Cannot find main.* … modules` 警告——这种目录布局下属正常现象。

## 配置

- 所有选项都在 `script-opts/modernz.conf` 中 —— 该文件已包含全部默认值，只需保留你要修改的行即可。
- 修改后重启 mpv 生效。

常用选项速查：

| 选项 | 作用 | 默认值 |
| --- | --- | --- |
| `language` | 界面语言（`default`、`zh`、`en` 等） | `default` |
| `layout` | 布局：`default` / `compact` / `mini` / `seekbar` | `default` |
| `icon_theme` | 图标主题：`fluent` / `material` | `fluent` |
| `icon_style` | 图标样式：`mixed` / `filled` / `outline` | `mixed` |
| `hidetimeout` | OSC 无操作自动隐藏的毫秒数 | `1500` |
| `fadeduration` | 淡入淡出时长（毫秒，0 表示无） | `200` |
| `deadzonesize` | 死区大小（0.0 = 任意移动即显示，1.0 = 仅悬停显示） | `0.75` |
| `visibility` | `auto` / `always` / `never` | `auto` |
| `osc_on_start` | 文件开始时显示 OSC（`no`/`bottom`/`top`/`both`） | `both` |
| `showonpause` | 暂停时显示 OSC | `yes` |
| `keeponpause` | 暂停时保持 OSC（`no`/`bottombar`/`both`） | `no` |
| `sub_margins` | 显示 OSC 时将字幕抬高到其上沿 | `yes` |
| `dynamic_margins` | 随 OSC 显隐动态应用边距 | `yes` |
| `osd_margins` | 同时调整 OSD 文字位置以避开 OSC | `no` |
| `persistent_progress` | 始终在底部显示一条细进度线 | `no` |
| `seekbar_height` | `small` / `medium` / `large` / `xlarge` | `medium` |
| `nibbles_style` | 章节标记：`gap`/`triangle`/`bar`/`single-bar` | `gap` |
| `download_path` | 下载按钮的保存目录 | `~~desktop/mpv` |
| `visibility_modes` | 循环切换可见性时按顺序轮换的模式 | `never_auto_always` |

## 操作

### 按钮交互

- 左键：主操作
- 右键：次操作
- 中键 / `Shift+左键`：备选操作

> 中键与 `Shift+左键` 功能相同，方便单手操作。

所有的鼠标操作都可以在 `modernz.conf` 中重新绑定，例如 `title_mbtn_left_command`、`seekbar_wheel_up_command`、`playlist_mbtn_right_command` 等。

### 按键绑定

ModernZ 默认**不**设置任何按键，以免与你的现有配置冲突。你可以按需在 `input.conf` 中添加：

```
v   script-binding modernz/visibility              # 循环切换可见性模式
V   script-message-to modernz osc-visibility cycle # 设置可见性：cycle, auto, always, never
w   script-binding modernz/progress-toggle         # 切换常驻进度条
x   script-message-to modernz osc-show             # 显示 OSC
y   script-message-to modernz osc-hide             # 隐藏 OSC
z   script-message-to modernz osc-idlescreen       # 切换待机画面
```

## 界面语言

界面语言由 `modernz.conf` 中的 `language` 选项控制（例如 `language=zh` 即简体中文）。可用的语言：`ar`、`de`、`dk`、`en`、`es`、`fr`、`is`、`jp`、`pl`、`ru`、`zh`。

如需贡献新语言，请参阅[上游翻译指南](https://github.com/Samillion/ModernZ/blob/main/docs/TRANSLATIONS.md)。

## 附带脚本

两个常与 ModernZ 搭配使用的脚本：

- [thumbfast](https://github.com/po5/thumbfast) —— 进度条上精确到帧的缩略图预览（配置在 `script-opts/thumbfast.conf`）。
- `acompressor.lua` —— 在屏幕上控制 ffmpeg 动态范围压缩滤镜。`n` 开关，`F1`/`Shift+F1` 调整阈值，`F2`/`Shift+F2` 调整压缩比。

下载按钮需要 [yt-dlp](https://github.com/yt-dlp/yt-dlp) 与 ffmpeg 位于 `PATH` 中。

## 常见问题

### 字幕被顶起，而且不会自动落回去

ModernZ 的 `sub_margins` 功能会在 OSC 显示时，通过临时降低 `sub-pos` 来抬高字幕。而在 mpv **0.36+** 中，默认的 `watch-later-options` 已包含 `sub-pos`，因此只要开启了位置记忆（`save-position-on-quit=yes`），在 OSC 还显示着的时候退出，被抬高的值就会被写进 `watch_later/`。下次播放时这个被抬高的 `sub-pos` 被恢复，并被误当成你真正设定的位置，于是字幕就一直悬在半空落不回去。

**该问题已由脚本自动处理，无需修改 `mpv.conf`。** 脚本在加载时会自动把 `sub-pos`（以及开启 `osd_margins=yes` 时的 `osd-margin-y`）从 `watch-later-options` 中移除，确保临时抬高永远不会被持久化。

> **如果你已经有被污染的记录：** 对于已存在的 `watch_later/*` 文件，mpv 会无视选项列表直接恢复其中的旧 `sub-pos=` 值。请把那一行（或整个文件）删除一次，之后不会再复发。

## 历史

- [Samillion/ModernZ](https://github.com/Samillion/ModernZ)
  - 衍生自 [dexeonify/ModernX](https://github.com/dexeonify/mpv-config/blob/main/scripts/modernx.lua)
    - 衍生自 [cyl0/ModernX](https://github.com/cyl0/ModernX)
      - 衍生自 [maoiscat/mpv-osc-modern](https://github.com/maoiscat/mpv-osc-modern)

**为什么还要再分叉一次？**

- 加入大量新功能，包括颜色自定义、高级选项与 locale 集成
- 将 mpv 的 `console` 与 `select` 功能整合进 OSC
- 引入专门针对图片查看优化的布局
- 加入 `fluent`/`material` 图标主题与 `mixed`/`filled`/`outline` 样式
- **按 mpv 官方 OSC 的标准重构项目**，保证长期兼容性
- 移除历史遗留的 bug 与冗余代码，提升可维护性与稳定性

本质上是为了维护并复兴 `modern-osc` 的起源。ModernZ 仍沿用部分旧代码，每一位前任与现任分叉作者、贡献者都应获得应有的致谢（包括 mpv 官方 OSC）。

#### 致谢：

- [Material Symbols](https://github.com/google/material-design-icons) by Google —— [Apache 2.0](https://github.com/google/material-design-icons?tab=Apache-2.0-1-ov-file#readme)
- [Fluent System Icons](https://github.com/microsoft/fluentui-system-icons) by Microsoft —— [MIT](https://github.com/microsoft/fluentui-system-icons?tab=MIT-1-ov-file#readme)
- [mpv](https://github.com/mpv-player/mpv) 及其 [osc.lua](https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua)，ModernZ 的 OSC 基于官方 OSC 标准重新实现
- 所有在[历史](#历史)中提到的现代 OSC 原作者及分叉
- 所有直接或间接帮助过 ModernZ 的贡献者、测试者与用户 ❤️

## HH-AA

<table>
  <tr>
    <td>
      - 永远的宁静怀念。<br>
      - 终有一日，在时间之外重逢。
  </td>
  </tr>
  <tr>
    <td>
      <img width="973" height="309" alt="c7dbd158" src="https://github.com/user-attachments/assets/416388f1-6b3f-4e9f-8be4-2364f8aa0c96" />
    </td>
  </tr>
</table>
