local M = {}

--[[
In normal mode, returns the entire buffer as a string.
In a visual selection mode, returns the selected text as a string.

Returns:
- text (string): The text that is currently visually selected.
]]
M.get_text = function()
    local bufnr = vim.api.nvim_get_current_buf()

    local mode = vim.fn.mode()
    if mode ~= 'v' and mode ~= 'V' and mode ~= '\22' then -- Visual, Visual Line, Visual Block
        -- Not in visual mode, return the entire buffer
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local buffer_text = table.concat(lines, '\n')
        return buffer_text
    end

    -- In a visual mode. Find the selected text.

    -- Get the start and end positions of the selected text
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
    local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')

    local start_line = start_pos[1]
    local start_col = start_pos[2] + 1
    local end_line = end_pos[1]
    local end_col = end_pos[2]

    if start_line > end_line or (start_line == end_line and start_col > end_col) then
        -- Swap positions if necessary
        start_line, end_line = end_line, start_line
        start_col, end_col = end_col, start_col
    end

    -- Get the lines in the selection
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
    if #lines == 0 then
        return ''
    end

    -- Adjust the first and last lines to account for the columns
    lines[1] = string.sub(lines[1], start_col)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)

    -- Concatenate the lines into a single string
    local selected_text = table.concat(lines, '\n')

    return selected_text
end

--[[
Splits a string into a table of lines.

Parameters:
- str (string): The string to split.

Returns:
- lines (table): A table containing each line as an element.
]]
M.split_lines = function(str)
    local lines = {}
    for line in str:gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

--[[
Opens a new scratch buffer in a split window.

Creates a new split window (vertical or horizontal depending on the dimensions of the current window),
creates a new scratch buffer in this window, and returns to the previous window. It also reselects
the previous visual selection.

Returns:
- out_buf (number): The buffer number of the new scratch buffer.
]]
M.open_scratch_buffer = function()
    -- Check the dimensions of the current window
    local win_width = vim.api.nvim_win_get_width(0)
    local win_height = vim.api.nvim_win_get_height(0)

    -- If the window is wider than it is tall, create a vertical split
    if win_width > win_height then
            vim.cmd('vsplit')
    else
            vim.cmd('split')
    end

    -- Create a new buffer
    local out_buf = vim.api.nvim_create_buf(false, true)

    -- Set the new buffer for the current window
    vim.api.nvim_win_set_buf(0, out_buf)

    -- Return to the previous window and reselect visual selection
    vim.cmd('wincmd p')
    vim.cmd('normal gv')

    return out_buf
end

return M
