local wezterm = require("wezterm")
local config = require("config")
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

tabline.setup({
	options = {
		icons_enabled = true,
		theme = "Rosé Pine (Gogh)",
		tabs_enabled = true,
		theme_overrides = {
			normal_mode = {
				c = { bg = "rgba(25, 23, 36, 0.88)" },
			},
			tab = {
				inactive = { bg = "rgba(25, 23, 36, 0.88)" },
			},
		},
		section_separators = {
			left = wezterm.nerdfonts.ple_right_half_circle_thick,
			right = wezterm.nerdfonts.ple_left_half_circle_thick,
		},
		component_separators = {
			left = wezterm.nerdfonts.ple_right_half_circle_thin,
			right = wezterm.nerdfonts.ple_left_half_circle_thin,
		},
		tab_separators = {
			-- left = wezterm.nerdfonts.ple_right_half_circle_thick,
			-- right = wezterm.nerdfonts.ple_left_half_circle_thick,
			left = "",
			right = "",
		},
	},
	sections = {
		tabline_a = { "mode" },
		tabline_b = { "workspace" },
		tabline_c = { "        " },
		tab_active = {
			"index",
			{ "parent", padding = 0 },
			"/",
			{ "cwd", padding = { left = 0, right = 1 } },
			{ "zoomed", padding = 0 },
		},
		tab_inactive = { "index", { "process", padding = { left = 0, right = 1 } } },
		tabline_x = { "ram", "cpu" },
		tabline_y = { "datetime", "battery" },
		tabline_z = { "hostname" },
	},
	extensions = {},
})

tabline.apply_to_config(config)
