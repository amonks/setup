-- https://github.com/overcache/NeoSolarized/blob/master/colors/NeoSolarized.vim
--
-- run this to see all the current colors and groups:
--     source $VIMRUNTIME/syntax/hitest.vim
--
-- run this to see the highlight at cursor:
--      Inspect

--@diagnostic disable: unused-local

local _base03 = "#002b36"
local _base02 = "#073642"
local _base01 = "#586e75"
local _base00 = "#657b83"
local _base0  = "#839496"
local _base1  = "#93a1a1"
local _base2  = "#eee8d5"
local _base3  = "#fdf6e3"

local highlighter
local base03
local base02
local base01
local base00
local base0
local base1
local base2
local base3

if vim.opt.background._value == "light" then
    highlighter = "#FFFF00"
    base03      = _base03
    base02      = _base02
    base01      = _base01
    base00      = _base00
    base0       = _base0
    base1       = _base1
    base2       = _base2
    base3       = _base3
elseif vim.opt.background._value == "dark" then
    highlighter = _base01
    base03      = _base3
    base02      = _base2
    base01      = _base1
    base00      = _base0
    base0       = _base00
    base1       = _base01
    base2       = _base02
    base3       = _base03
else
    base00 = "#FF00FF"
end

local yellow  = "#b58900"
local orange  = "#cb4b16"
local red     = "#dc322f"
local magenta = "#d33682"
local violet  = "#6c71c4"
local blue    = "#268bd2"
local cyan    = "#2aa198"
local green   = "#719e07"


local ui                  = { bg = base2, fg = base02 }
local prose               = { italic = true, bold = true, fg = base03 }
local code                = { fg = base02 }
local usertext            = { italic = true, fg = green }
local marked              = { bg = highlighter }
local ctrlflow_break      = { fg = magenta }
local ctrlflow_internal   = { fg = yellow }
local ctrlflow_concurrent = { fg = cyan }


vim.cmd([[
    hi clear
    if exists("syntax_on")
        syntax reset
    endif
]])


local function hi(group, vals)
    vim.api.nvim_set_hl(0, group, vals)
end

-- UI Chrome

hi("SignColumn", ui)
hi("GitGutterAdd", { bg = ui.bg, fg = green })
hi("GitGutterChange", { bg = ui.bg, fg = yellow })
hi("GitGutterDelete", { bg = ui.bg, fg = red })

hi("StatusLine", ui)                        -- focused window
hi("StatusLineNC", { bg = ui.bg, fg = base00 }) -- non-focused window

hi("CursorLine", { bg = "NONE" })
hi("Pmenu", { bg = ui.bg, fg = base01 })    -- popups

hi("Visual", marked)

-- hi("LineNr",       { fg=base2, italic=true })
-- hi("CursorLineNr", { fg=blue, italic=true })


-- Text

hi("Normal", { fg = code.fg, bg = "NONE" })

hi("Comment", prose)
hi("Title", code)
hi("TODO", marked)
hi("Special", code)     -- PUNCTUATION

hi("Constant", code)
hi("Define", code)
hi("Macro", code)
hi("String", usertext)
hi("SpecialChar", usertext)
hi("CharData", usertext)
hi("@string", usertext)
hi("@none.tsx", usertext)
hi("Character", code)
hi("Number", code)
hi("Boolean", code)
hi("Float", code)

hi("Function", code)
hi("Parameter", code)
hi("@constructor", code)

hi("Statement", code)
hi("Conditional", code)
hi("Label", code)
hi("Operator", code)
hi("Keyword", code)

hi("@keyword.function.go", ctrlflow_break)
hi("@keyword.return", ctrlflow_break)
hi("Exception", ctrlflow_break)
hi("@keyword.exception", ctrlflow_break)
hi("@keyword.ts.try", code)
hi("@keyword.ts.catch", code)
hi("@operator.arrow", ctrlflow_internal)
hi("@keyword.coroutine.go", ctrlflow_concurrent)
hi("@keyword.coroutine.typescript", ctrlflow_concurrent)
hi("@keyword.defer.go", ctrlflow_concurrent)
hi("Repeat", ctrlflow_internal)
hi("@keyword.continue.go", ctrlflow_internal)
hi("@keyword.break.go", ctrlflow_internal)
hi("@keyword.goto.go", ctrlflow_internal)

hi("Identifier", code)

hi("@namespace.go", code)
hi("Type", code)
hi("Typedef", code)
hi("StorageClass", code)
hi("Structure", code)
hi("Include", code)
hi("PreProc", code)
hi("Debug", code)
hi("Tag", code)
