-- cutiepro for Neovim: the cutiepro Zed port (github.com/wakaranakattari/cutiepro-zed,
-- themes/cutiepro.json) with its exact colors, like Helix's themes/cutiepro.toml. The editor has no
-- background, so Ghostty's (#181818) shows through; Zed colors with alpha (#rrggbbaa) are blended
-- onto #181818, as Zed draws them.

local background = "#181818"

-- Composite a #rrggbbaa color onto the background.
local function blend(rgba)
  local alpha = tonumber(rgba:sub(8, 9), 16) / 255
  local rgb = {}
  for i = 2, 6, 2 do
    local over, under = tonumber(rgba:sub(i, i + 1), 16), tonumber(background:sub(i, i + 1), 16)
    rgb[#rgb + 1] = math.floor(over * alpha + under * (1 - alpha) + 0.5)
  end
  return string.format("#%02x%02x%02x", unpack(rgb))
end

-- Zed `style` keys
local zed = {
  ["editor.background"] = background,
  ["editor.active_line.background"] = "#242628",
  ["editor.line_number"] = "#88847f",
  ["editor.active_line_number"] = "#e5a1a3",
  ["editor.invisible"] = "#88847f",
  ["editor.wrap_guide"] = "#2e2a27",
  ["editor.indent_guide"] = "#2e2a27",
  ["editor.indent_guide_active"] = "#88847f",
  ["editor.document_highlight.read_background"] = blend("#e5a1a31a"),
  ["editor.document_highlight.write_background"] = blend("#88847f40"),
  ["editor.document_highlight.bracket_background"] = blend("#38383880"),
  ["elevated_surface.background"] = "#181818",
  ["element.selected"] = "#383838",
  ["border"] = "#2e2a27",
  ["pane_group.border"] = "#2e2a27",
  ["status_bar.background"] = "#181818",
  ["tab_bar.background"] = "#181818",
  ["text"] = "#d5d0c9",
  ["text.muted"] = "#88847f",
  ["text.accent"] = "#e5a1a3",
  ["search.match_background"] = blend("#e5a1a366"),
  ["search.active_match_background"] = blend("#e5a1a3aa"),
  ["scrollbar.thumb.background"] = blend("#e5a1a380"),
  ["error"] = "#f56e7f",
  ["warning"] = "#f3b061",
  ["info"] = "#80c5de",
  ["hint"] = "#88847f",
  ["success"] = "#bec975",
  ["version_control.added"] = "#bec975",
  ["version_control.modified"] = blend("#E5A1A3CC"),
  ["version_control.deleted"] = "#f56e7f",
  ["players[0].cursor"] = "#e5a1a3",
  ["players[0].selection"] = "#383838",
}

-- Zed `syntax` keys. Keys with no Neovim capture (embedded, primary, selector,
-- selector.pseudo, punctuation.markup) are left out.
local syntax = {
  ["attribute"] = { fg = "#f4b86a" },
  ["comment"] = { fg = "#88847f" },
  ["comment.doc"] = { fg = "#88847f", italic = true },
  ["constant"] = { fg = "#e5a1a3" },
  ["constructor"] = { fg = "#f58669" },
  ["emphasis"] = { fg = "#d5d0c9", italic = true },
  ["emphasis.strong"] = { fg = "#d7c3ba", bold = true },
  ["function"] = { fg = "#caa2ca" },
  ["function.builtin"] = { fg = "#caa2ca", italic = true },
  ["function.method"] = { fg = "#caa2ca" },
  ["function.macro"] = { fg = "#97ca95" },
  ["keyword"] = { fg = "#f56e7f" },
  ["label"] = { fg = "#97ca95" },
  ["link_text"] = { fg = "#ef7dc0" },
  ["link_uri"] = { fg = "#ef7dc0" },
  ["number"] = { fg = "#a5b6ce" },
  ["operator"] = { fg = "#e8d6a7" },
  ["predictive"] = { fg = "#88847f", italic = true },
  ["preproc"] = { fg = "#caa2ca" },
  ["property"] = { fg = "#e5a1a3" },
  ["punctuation.bracket"] = { fg = "#e8d6a7" },
  ["punctuation.delimiter"] = { fg = "#e8d6a7" },
  ["punctuation.list_marker"] = { fg = "#e5a1a3" },
  ["punctuation.special"] = { fg = "#e8d6a7" },
  ["string"] = { fg = "#bec975" },
  ["string.regex"] = { fg = "#bec975" },
  ["string.special"] = { fg = "#a5b6ce" },
  ["string.special.symbol"] = { fg = "#a5b6ce" },
  ["tag"] = { fg = "#f56e7f" },
  ["text.literal"] = { fg = "#bec975" },
  ["title"] = { fg = "#e5a1a3", bold = true },
  ["type"] = { fg = "#f58669" },
  ["type.builtin"] = { fg = "#5dccc3" },
  ["type.parameter"] = { fg = "#5dccc3" },
  ["variable"] = { fg = "#e5a1a3" },
  ["variable.special"] = { fg = "#e5a1a3" },
}

local search = { bg = zed["search.match_background"] }
local active_search = { bg = zed["search.active_match_background"] }
local invisible = { fg = zed["editor.invisible"] }
local separator = { fg = zed["border"] }
local float = zed["elevated_surface.background"]

local groups = {
  -- Editor UI. No background on the editor, gutter or floats, so Ghostty's translucent window
  -- shows through; menus, the status line and the tab line stay #181818.
  Normal = { fg = zed["text"] },
  NormalNC = { fg = zed["text"] },
  NormalFloat = { fg = zed["text"] },
  FloatBorder = { fg = zed["border"] },
  FloatTitle = { fg = zed["text.accent"] },
  Cursor = { fg = zed["editor.background"], bg = zed["players[0].cursor"] },
  CursorLine = { bg = zed["editor.active_line.background"] },
  CursorColumn = { bg = zed["editor.active_line.background"] },
  LineNr = { fg = zed["editor.line_number"] },
  CursorLineNr = { fg = zed["editor.active_line_number"] },
  SignColumn = {},
  FoldColumn = { fg = zed["text.muted"] },
  Folded = { fg = zed["text.muted"], bg = zed["editor.active_line.background"] },
  Visual = { bg = zed["players[0].selection"] },
  Search = search,
  CurSearch = active_search,
  MatchParen = { bg = zed["editor.document_highlight.bracket_background"] },
  ColorColumn = { bg = zed["editor.wrap_guide"] },
  WinSeparator = { fg = zed["pane_group.border"] },
  NonText = invisible,
  SpecialKey = invisible,
  StatusLine = { fg = zed["text"], bg = zed["status_bar.background"] },
  StatusLineNC = { fg = zed["text.muted"], bg = zed["status_bar.background"] },
  TabLineFill = { bg = zed["tab_bar.background"] },
  TabLineSel = { fg = zed["editor.background"], bg = zed["error"] },
  WinBar = { fg = zed["text"] },
  WinBarNC = { fg = zed["text.muted"] },
  Pmenu = { fg = zed["text"], bg = float },
  PmenuSel = { bg = zed["element.selected"] },
  PmenuSbar = { bg = float },
  PmenuThumb = { bg = zed["scrollbar.thumb.background"] },
  QuickFixLine = { bg = zed["element.selected"] },
  Title = syntax["title"],
  Directory = { fg = zed["text.accent"] },
  Conceal = { fg = zed["text.muted"] },
  ModeMsg = { fg = zed["text"] },
  MoreMsg = { fg = zed["text.accent"] },
  Question = { fg = zed["text.accent"] },
  ErrorMsg = { fg = zed["error"] },
  WarningMsg = { fg = zed["warning"] },
  SpellBad = { undercurl = true, sp = zed["error"] },
  SpellCap = { undercurl = true, sp = zed["warning"] },
  SpellLocal = { undercurl = true, sp = zed["info"] },
  SpellRare = { undercurl = true, sp = zed["info"] },

  -- Diagnostics and LSP
  DiagnosticError = { fg = zed["error"] },
  DiagnosticWarn = { fg = zed["warning"] },
  DiagnosticInfo = { fg = zed["info"] },
  DiagnosticHint = { fg = zed["hint"] },
  DiagnosticOk = { fg = zed["success"] },
  DiagnosticUnderlineError = { undercurl = true, sp = zed["error"] },
  DiagnosticUnderlineWarn = { undercurl = true, sp = zed["warning"] },
  DiagnosticUnderlineInfo = { undercurl = true, sp = zed["info"] },
  DiagnosticUnderlineHint = { undercurl = true, sp = zed["hint"] },
  DiagnosticUnderlineOk = { undercurl = true, sp = zed["success"] },
  LspReferenceText = { bg = zed["editor.document_highlight.read_background"] },
  LspReferenceWrite = { bg = zed["editor.document_highlight.write_background"] },

  -- Version control. gitsigns links to Added/Changed/Removed. Zed has no diff-line
  -- backgrounds, so DiffAdd/DiffChange/DiffDelete/DiffText tint the same colors at 15-25%.
  Added = { fg = zed["version_control.added"] },
  Changed = { fg = zed["version_control.modified"] },
  Removed = { fg = zed["version_control.deleted"] },
  DiffAdd = { bg = blend("#bec97526") },
  DiffChange = { bg = blend("#e5a1a326") },
  DiffDelete = { bg = blend("#f56e7f26") },
  DiffText = { bg = blend("#e5a1a340") },

  -- Plugins (LazyVim's snacks indent guides, blink.cmp ghost text and bufferline separators)
  SnacksIndent = { fg = zed["editor.indent_guide"] },
  SnacksIndentScope = { fg = zed["editor.indent_guide_active"] },
  SnacksIndent1 = { fg = blend(syntax["variable"].fg .. "33") },
  SnacksIndent2 = { fg = blend(syntax["type"].fg .. "33") },
  SnacksIndent3 = { fg = blend(syntax["operator"].fg .. "33") },
  SnacksIndent4 = { fg = blend(syntax["string"].fg .. "33") },
  SnacksIndent5 = { fg = blend(syntax["number"].fg .. "33") },
  SnacksIndent6 = { fg = blend(syntax["function"].fg .. "33") },
  SnacksIndentScope1 = { fg = blend(syntax["variable"].fg .. "66") },
  SnacksIndentScope2 = { fg = blend(syntax["type"].fg .. "66") },
  SnacksIndentScope3 = { fg = blend(syntax["operator"].fg .. "66") },
  SnacksIndentScope4 = { fg = blend(syntax["string"].fg .. "66") },
  SnacksIndentScope5 = { fg = blend(syntax["number"].fg .. "66") },
  SnacksIndentScope6 = { fg = blend(syntax["function"].fg .. "66") },
  BlinkCmpGhostText = syntax["predictive"],
  BufferLineSeparator = separator,
  BufferLineSeparatorVisible = separator,
  BufferLineSeparatorSelected = separator,
  BufferLineTabSeparator = separator,
  BufferLineTabSeparatorSelected = separator,

  -- Legacy syntax groups, for filetypes without tree-sitter and plugins that link to them
  Comment = syntax["comment"],
  Constant = syntax["constant"],
  String = syntax["string"],
  Character = syntax["string"],
  Number = syntax["number"],
  Identifier = syntax["variable"],
  Function = syntax["function"],
  Statement = syntax["keyword"],
  Label = syntax["label"],
  Operator = syntax["operator"],
  PreProc = syntax["preproc"],
  Include = syntax["keyword"],
  Define = syntax["function.macro"],
  Macro = syntax["function.macro"],
  Type = syntax["type"],
  Special = syntax["string.special"],
  Tag = syntax["tag"],
  Delimiter = syntax["punctuation.delimiter"],
  SpecialComment = syntax["comment.doc"],
  Error = { fg = zed["error"] },
  Todo = { fg = zed["warning"], bold = true },

  -- Tree-sitter captures whose Neovim default (a link to a group above, or the parent capture
  -- @a.b -> @a) would give a different color than the Zed port.
  ["@attribute"] = syntax["attribute"],
  ["@comment.documentation"] = syntax["comment.doc"],
  ["@constructor"] = syntax["constructor"],
  ["@function.builtin"] = syntax["function.builtin"],
  ["@function.method"] = syntax["function.method"],
  ["@function.macro"] = syntax["function.macro"],
  ["@keyword.directive"] = syntax["preproc"],
  ["@variable.member"] = syntax["property"],
  ["@punctuation.bracket"] = syntax["punctuation.bracket"],
  ["@punctuation.delimiter"] = syntax["punctuation.delimiter"],
  ["@punctuation.special"] = syntax["punctuation.special"],
  ["@string.regexp"] = syntax["string.regex"],
  ["@string.special.symbol"] = syntax["string.special.symbol"],
  ["@string.special.url"] = syntax["link_uri"],
  ["@tag.attribute"] = syntax["attribute"],
  ["@tag.delimiter"] = syntax["punctuation.bracket"],
  ["@type.builtin"] = syntax["type.builtin"],
  ["@variable"] = syntax["variable"],
  ["@variable.builtin"] = syntax["variable.special"],
  ["@markup.italic"] = syntax["emphasis"],
  ["@markup.strong"] = syntax["emphasis.strong"],
  ["@markup.raw"] = syntax["text.literal"],
  ["@markup.list"] = syntax["punctuation.list_marker"],
  ["@markup.link"] = syntax["link_text"],
  ["@markup.link.url"] = syntax["link_uri"],

  -- LSP semantic tokens whose Neovim default would override tree-sitter with a different color
  -- (e.g. rust-analyzer marks println! as a macro)
  ["@lsp.type.typeParameter"] = syntax["type.parameter"],
  ["@lsp.type.macro"] = syntax["function.macro"],
  ["@lsp.type.builtinType"] = syntax["type.builtin"],
  ["@lsp.type.selfKeyword"] = syntax["variable.special"],
}

vim.cmd("highlight clear")
if vim.g.syntax_on then
  vim.cmd("syntax reset")
end
-- Only when needed: setting 'background' fires the OptionSet autocmd in config/autocmds.lua.
if vim.o.background ~= "dark" then
  vim.o.background = "dark"
end
vim.g.colors_name = "cutiepro"

for name, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, name, spec)
end
-- No terminal_color_N: unset, :terminal sends palette indexes to Ghostty, so Ghostty's own palette
-- and its bold-color = bright apply. Set, Neovim sends fixed RGB and bold stays the normal color.
-- Cleared in case rose-pine (light mode) set them.
for i = 0, 15 do
  vim.g["terminal_color_" .. i] = nil
end
