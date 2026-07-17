local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- ── Theme ──────────────────────────────────────────────────────────────────
config.color_scheme = "rose-pine-moon"

-- ── Font ──────────────────────────────────────────────────────────────────
config.font       = wezterm.font("Hack Nerd Font", { weight = "DemiBold" })
config.font_size  = 15.0

-- ── Window frame (title bar area font) ────────────────────────────────────
config.window_frame = {
  font      = wezterm.font("Hack Nerd Font"),
  font_size = 13.0,
}

-- ── Window chrome ─────────────────────────────────────────────────────────
-- INTEGRATED_BUTTONS keeps the macOS traffic-light close/min/max buttons
-- inside the tab bar instead of floating above it - cleaner look.
config.window_decorations          = "RESIZE"
config.window_background_opacity   = 0.8
config.macos_window_background_blur = 50
config.hide_tab_bar_if_only_one_tab = true

-- ── Performance ───────────────────────────────────────────────────────────
config.max_fps = 120   -- smoother scrolling and cursor

-- ── Focus: dim inactive panes so you always know where you are ────────────
config.inactive_pane_hsb = {
  saturation = 0.0,   -- desaturate
  brightness = 0.5,   -- darken
}

return config
