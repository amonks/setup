-- keyboard mapping helpers

function map(mode, shortcut, command, extra)
    opts = { noremap = true, silent = true }
    for k,v in pairs(extra or {}) do
        opts[k] = v
    end
    vim.keymap.set(mode, shortcut, command, opts)
end
function nmap(shortcut, command, extra) map('n', shortcut, command, extra) end
function imap(shortcut, command, extra) map('i', shortcut, command, extra) end
function vmap(shortcut, command, extra) map('v', shortcut, command, extra) end

function mapcmd(mode, shortcut, command, extra)
    opts = { noremap = true, silent = true }
    for k,v in pairs(extra or {}) do
        opts[k] = v
    end
    vim.api.nvim_set_keymap(mode, shortcut, command, opts)
end
function nmapcmd(shortcut, command, extra) map('n', shortcut, command, extra) end
function imapcmd(shortcut, command, extra) map('i', shortcut, command, extra) end
function vmapcmd(shortcut, command, extra) map('v', shortcut, command, extra) end

