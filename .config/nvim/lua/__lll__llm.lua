local M = {}

local A = require('async')
local U = require('util')
local K = require('libmap')

local function get_models()
    local models = {}
    local result = vim.system({ 'llm', 'models', 'list' }):wait()
    for line in result.stdout:gmatch("(.-)\n") do
        local model = line:match("^[^:]+: ([^%s]+)")
        table.insert(models, model)
    end
    return models
end

local function execute_llm(model, prompt, text)
    local command = { 'bllm', '-m', model, prompt }
    local lineno = 0

    local out_buf = U.open_scratch_buffer()

    -- Define a callback function to handle stdout data
    local function handle_stdout(err, data)
        if err ~= '' and err ~= nil then
            return
        end
        if not data then
            return
        end

        local lines = U.split_lines(data)
        local this_lineno = lineno
        lineno = lineno + #lines

        vim.schedule(function()
            vim.api.nvim_buf_set_lines(out_buf, this_lineno, this_lineno, false, lines)
        end)
    end

    local function handle_exit(result)
        if result.code ~= 0 then
            vim.schedule(function()
                local errorMsg = ('Error executing command: %s\nExit code: %d'):format(table.concat(command, " "), result.code)
                vim.notify(errorMsg, vim.log.levels.ERROR)
                vim.notify(result.stderr, vim.log.levels.ERROR)
            end)
        end
    end

    -- Set up the `vim.system` call to include the stdout callback and input for stdin
    vim.system(command, {
        stdout = handle_stdout, -- Use the callback for stdout
        stdin = text,           -- Send the text to stdin
        text = true,
    }, handle_exit)
end

-- Main function to prompt the LLM
M.prompt_llm = A.go(function(await)
    local text = U.get_text()
    if not text then
        return
    end

    local prompt = await(A.input, { prompt = 'Enter prompt: ' })
    if not prompt then
        return
    end

    local model = await(A.select, get_models(), {})
    if not model then
        return
    end

    execute_llm(model, prompt, text)
end)

-- Create a user command to invoke the plugin
vim.api.nvim_create_user_command('LLMPrompt', M.prompt_llm, { range = true })
K.vmap('<leader>lp', M.prompt_llm)

return M
