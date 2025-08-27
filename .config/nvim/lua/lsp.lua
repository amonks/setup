local mason = require('mason')
mason.setup()

require('mason-lock').setup()

require('mason-lspconfig').setup()


local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

local on_attach = function(client, bufnr)
    -- avoid formatting conflict between ts_ls and prettier
    if client.name == "ts_ls" then
        client.server_capabilities.documentFormattingProvider = false
    end

    -- make null-ls format on save when possible
    if client.name == "null-ls" then
        if client.supports_method("textDocument/formatting") then
            vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
            vim.api.nvim_create_autocmd("BufWritePre", {
                group = augroup,
                buffer = bufnr,
                callback = function()
                    vim.lsp.buf.format({ bufnr = bufnr, async = false })
                end,
                desc = "[lsp] format on save",
            })
        end
    end

    -- enable completion triggered by <C-x><C-o>
    vim.api.nvim_set_option_value("omnifunc", "v:lua.vim.lsp.omnifunc", {
        buf = bufnr,
    })

    local extra = { buffer = bufnr }
    local k = require('libmap')
    k.nmap("gD", vim.lsp.buf.type_definition, extra)
    k.nmap("gd", vim.lsp.buf.definition, extra)
    k.nmap("gr", vim.lsp.buf.references, extra)

    k.nmap("K", vim.lsp.buf.hover, extra)
    k.nmap("gi", vim.lsp.buf.implementation, extra)

    k.nmap("<C-k>", vim.lsp.buf.signature_help, extra)
    k.imap("<C-k>", vim.lsp.buf.signature_help, extra)

    k.nmap("[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, extra)
    k.nmap("]d", function() vim.diagnostic.jump({ count = 1,  float = true }) end, extra)

    k.nmap("<space>rn", vim.lsp.buf.rename, extra)
    k.nmap("<space>ca", vim.lsp.buf.code_action, extra)
    k.nmap("<space>f", function() vim.lsp.buf.format({ async = true }) end, extra)
end

local null_ls = require("null-ls")
null_ls.setup({
    debug = true,
    on_attach = on_attach,
    sources = {
        null_ls.builtins.formatting.prettierd,
    },
})

local lspconfig = require("lspconfig")
lspconfig["lua_ls"].setup({
    on_attach = on_attach,
    diagnostics = {
        globals = {
            "vim"
        }
    },
})
lspconfig["eslint"].setup({ on_attach = on_attach })
lspconfig["ts_ls"].setup({ on_attach = on_attach })
lspconfig["templ"].setup({ on_attach = on_attach })
lspconfig["ruff"].setup({ on_attach = on_attach })
lspconfig["basedpyright"].setup({ on_attach = on_attach })
lspconfig["gopls"].setup({
    on_attach = on_attach,
    settings = {
        gopls = {
            env = {
                GOFLAGS = "--tags=linux,wasm,js,fts5,sqlite_math_functions"
            }
        }
    }
})

-- workaround for buggy lsp implementations
-- https://github.com/neovim/neovim/issues/12970
vim.lsp.util.apply_text_document_edit = function(text_document_edit, _, offset_encoding)
    local text_document = text_document_edit.textDocument
    local bufnr = vim.uri_to_bufnr(text_document.uri)
    if offset_encoding == nil then
        vim.notify_once('apply_text_document_edit must be called with valid offset encoding', vim.log.levels.WARN)
    end

    vim.lsp.util.apply_text_edits(text_document_edit.edits, bufnr, offset_encoding)
end
