-- markdown-specific settings

-- Create an autocommand group for markdown files
local markdown_group = vim.api.nvim_create_augroup("MarkdownSettings", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
    group = markdown_group,
    pattern = "markdown",
    callback = function()
        -- Enable soft wrapping (visual wrap without changing file)
        vim.opt_local.wrap = true

        -- Wrap at word boundaries, not in the middle of words
        vim.opt_local.linebreak = true

        -- Enable breakindent for proper hanging indent on wrapped lines
        vim.opt_local.breakindent = true

        -- Disable textwidth to prevent hard wrapping
        vim.opt_local.textwidth = 0

        -- Remove 't' from formatoptions to prevent auto-wrapping text
        vim.opt_local.formatoptions:remove("t")

        -- Optional: Show a marker for wrapped lines (you can customize or remove this)
        vim.opt_local.showbreak = "↪ "

        -- Optional: Preserve indent structure when wrapping
        vim.opt_local.preserveindent = true
    end
})
