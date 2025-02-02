local M = {}

-- keyboard mapping helpers

M.map = function(mode, shortcut, command, extra)
    local opts = { noremap = true, silent = true }
    for k,v in pairs(extra or {}) do
        opts[k] = v
    end
    vim.keymap.set(mode, shortcut, command, opts)
end
M.nmap = function (shortcut, command, extra) M.map('n', shortcut, command, extra) end
M.imap = function(shortcut, command, extra)  M.map('i', shortcut, command, extra) end
M.vmap = function(shortcut, command, extra)  M.map('v', shortcut, command, extra) end

M.mapcmd = function(mode, shortcut, command, extra)
    local opts = { noremap = true, silent = true }
    for k,v in pairs(extra or {}) do
        opts[k] = v
    end
    vim.api.nvim_set_keymap(mode, shortcut, command, opts)
end
M.nmapcmd = function(shortcut, command, extra) M.mapcmd('n', shortcut, command, extra) end
M.imapcmd = function(shortcut, command, extra) M.mapcmd('i', shortcut, command, extra) end
M.vmapcmd = function(shortcut, command, extra) M.mapcmd('v', shortcut, command, extra) end

return M
