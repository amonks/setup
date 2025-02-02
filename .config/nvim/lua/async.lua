local M = {}

M.go = function(fn)
    local co = coroutine.create(fn)

    local resume = function(...)
        local args = { ... }
        vim.schedule(function()
            coroutine.resume(co, unpack(args))
        end)
    end

    -- f must take a callback as its first parameter
    local await = function(f, ...)
        f(resume, ...)
        return coroutine.yield()
    end

    return function()
        coroutine.resume(co, await)
    end
end

-- convert functions to take callback first, so varargs in await work properly
M.input =  function(cb, opts)        vim.ui.input(opts, cb)         end
M.select = function(cb, items, opts) vim.ui.select(items, opts, cb) end

return M
