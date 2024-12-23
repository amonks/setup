local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
local group = vim.api.nvim_create_augroup("lsp_format_on_save", { clear = false })

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
    vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

    local extra = { buffer = bufnr }
    nmap("gD", vim.lsp.buf.type_definition, extra)
    nmap("gd", vim.lsp.buf.definition, extra)
    nmap("gr", vim.lsp.buf.references, extra)

    nmap("K", vim.lsp.buf.hover, extra)
    nmap("gi", vim.lsp.buf.implementation, extra)

    nmap("<C-k>", vim.lsp.buf.signature_help, extra)
    imap("<C-k>", vim.lsp.buf.signature_help, extra)

    nmap("[d", vim.diagnostic.goto_prev, extra)
    nmap("]d", vim.diagnostic.goto_next, extra)

    nmap("<space>rn", vim.lsp.buf.rename, extra)
    nmap("<space>ca", vim.lsp.buf.code_action, extra)
    nmap("<space>f", function() vim.lsp.buf.format({ async = true }) end, extra)
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
lspconfig["eslint"].setup({ on_attach = on_attach })
lspconfig["ts_ls"].setup({ on_attach = on_attach })
lspconfig["templ"].setup({ on_attach = on_attach })
lspconfig["ruff"].setup({ on_attach = on_attach })
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
vim.lsp.util.apply_text_document_edit = function(text_document_edit, index, offset_encoding)
    local text_document = text_document_edit.textDocument
    local bufnr = vim.uri_to_bufnr(text_document.uri)
    if offset_encoding == nil then
        vim.notify_once('apply_text_document_edit must be called with valid offset encoding', vim.log.levels.WARN)
    end

    vim.lsp.util.apply_text_edits(text_document_edit.edits, bufnr, offset_encoding)
end
