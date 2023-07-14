-- https://github.com/overcache/NeoSolarized/blob/master/colors/NeoSolarized.vim
--
-- run this to see all the current colors and groups:
--     source $VIMRUNTIME/syntax/hitest.vim
--
-- run this to see the highlight at cursor:
--      Inspect

_base03  = "#002b36"
_base02  = "#073642"
_base01  = "#586e75"
_base00  = "#657b83"
_base0   = "#839496"
_base1   = "#93a1a1"
_base2   = "#eee8d5"
_base3   = "#fdf6e3"

if vim.opt.background._value == "light" then
    base03 = _base03
    base03 = _base03
    base02 = _base02
    base01 = _base01
    base00 = _base00
    base0 = _base0
    base1 = _base1
    base2 = _base2
    base3 = _base3
elseif vim.opt.background._value == "dark" then
    base03 = _base3
    base03 = _base3
    base02 = _base2
    base01 = _base1
    base00 = _base0
    base0 = _base00
    base1 = _base01
    base2 = _base02
    base3 = _base03
else
    base00="#FF00FF"
end

highlighter  = "#FFFF00"
yellow  = "#b58900"
orange  = "#cb4b16"
red     = "#dc322f"
magenta = "#d33682"
violet  = "#6c71c4"
blue    = "#268bd2"
cyan    = "#2aa198"
green   = "#719e07"


prose    = { italic=true, fg=violet }
code     = { fg=base00 }
ctrlflow = { fg=red }
usertext = { fg=violet, italic=true }
marked   = { bg=highlighter }
name     = { fg=base00 }


vim.cmd([[
    hi clear
    if exists("syntax_on")
        syntax reset
    endif
]])


function hi(group, vals)
    vim.api.nvim_set_hl(0, group, vals)
end

-- UI Chrome

hi("StatusLine", { bg=base2, fg=base01 })
hi("StatusLineNC", { bg=base2, fg=base00 })
hi("CursorLine",  { bg="NONE" })
hi("Pmenu",       { bg=base2, fg=base01 })

hi("Visual",      { bg=highlighter })

hi("LineNr",      code)
hi("CursorLineNr",{ fg=blue })

-- Text

hi("Normal",      { fg=base00, bg="NONE" })

hi("Comment",     prose)
hi("Title",       code)
hi("TODO",        { bg=highlighter })
hi("Special",     code) -- PUNCTUATION

hi("Constant",    name)
hi("Define",      code)
hi("Macro",       code)
hi("String",      usertext)
hi("SpecialChar", usertext)
hi("Character",   code)
hi("Number",      code)
hi("Boolean",     code)
hi("Float",       code)

hi("Function",    code)
hi("Parameter",   code)
hi("@constructor", code)

hi("Conditional", code)
hi("Repeat",      code)
hi("Label",       code)
hi("Operator",    code)
hi("Keyword",     code)
hi("@keyword.return", ctrlflow)
hi("@keyword.defer",  ctrlflow)
hi("Exception",   code)

hi("Identifier",  name)
hi("@namespace.go",  code)
hi("Type",        code)
hi("Typedef",     code)
hi("StorageClass",code)
hi("Structure",   code)
hi("Include",     code)
hi("PreProc",     code)
hi("Debug",       code)
hi("Tag",         code)
