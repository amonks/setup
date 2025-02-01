local M = {}

local function get_models()
  local models = {}
  local result = vim.system({'llm', 'models', 'list'}):wait()
  for line in result.stdout:gmatch("(.-)\n") do
    local model = line:match("^[^:]+: ([^%s]+)")
    table.insert(models, model)
  end
  return models
end

-- Function to get the visual selection
local function get_visual_selection()
  local bufnr = vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()

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

local function open_output_buffer()
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

    -- Return to the previous window
    vim.cmd('wincmd p')
    vim.cmd('normal gv')

    return out_buf
end

function split_lines(str)
    local lines = {}
    for line in str:gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function execute_llm(model, prompt, text)
  local command = { 'bllm', '-m', model, prompt }
  local lineno = 0

  local out_buf = open_output_buffer()

  -- Define a callback function to handle stdout data
  local function handle_stdout(err, data)
    if err ~= '' and err ~= nil then
      return
    end
    if data == '' or data == nil then
      return
    end

    local lines = split_lines(data)
    local this_lineno = lineno
    lineno = lineno + #lines

    vim.schedule(function()
      vim.api.nvim_buf_set_lines(out_buf, this_lineno, this_lineno, false, lines)
    end)
  end

  local function handle_exit(result)
    if result.code ~= 0 then
      vim.schedule(function()
        -- Notify the user about the error
        vim.notify(result.stderr, vim.log.levels.ERROR)
        vim.notify('llm command exited with code ' .. result.code, vim.log.levels.ERROR)
      end)
    end
  end

  -- Set up the `vim.system` call to include the stdout callback and input for stdin
  local result = vim.system(command, {
    stdout = handle_stdout,  -- Use the callback for stdout
    stdin = text,            -- Send the text to stdin
    text = true,
  }, handle_exit)
end

-- Main function to prompt the LLM
function M.prompt_llm()
  get_models()

  local selected_text = get_visual_selection()
  if selected_text == '' then
    return
  end

  -- Prompt the user for input
  vim.ui.input({ prompt = 'Enter prompt: ' }, function(prompt)
    if prompt == nil or prompt == '' then
      return
    end

    vim.ui.select(get_models(), {}, function(model)
      if model == nil or model == '' then
        return
      end

      execute_llm(model, prompt, selected_text)
    end)
  end)
end

-- Create a user command to invoke the plugin
vim.api.nvim_create_user_command('LLMPrompt', M.prompt_llm, { range = true })

-- Optional key mapping in visual mode (adjust as needed)
vim.api.nvim_set_keymap('v', '<leader>lp', '<Esc>:LLMPrompt<CR>', { noremap = true, silent = true })

return M
