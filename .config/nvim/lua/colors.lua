-- color scheme

local K = require('libmap')

vim.opt.termguicolors = true

local function set_theme(theme)
    vim.opt.background = theme
    vim.cmd.colorscheme("monks")
end

local function sync_theme()
    vim.fn.system("grep 'light mode' ~/.config/alacritty/alacritty.yml")
    if vim.v.shell_error == 0 then
        set_theme("light")
    else
        set_theme("dark")
    end
end
sync_theme()

K.nmap("<F6>", function ()
    vim.fn.system("fish -c toggle-night-mode")
    sync_theme()
end)

