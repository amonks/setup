return function()
  local mode = require('model').mode
  local anthropic_provider = require('model.providers.anthropic')
  local openai_provider = require('model.providers.openai')

  require('model.providers.openai').initialize({
    model = 'gpt-o1'
  })

  function clone(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[clone(k, s)] = clone(v, s) end
    return res
  end

  function builder(fn)
    return function(opt)
      dup = clone(opt)
      fn(dup)
      return dup
    end
  end


  -- Prompt Builders

  build_prompter = function(prompt_builders)
    return builder(function(opt)
      opt.builder = function(input, context)
        msgs = {}
        for i,builder in ipairs(prompt_builders) do
          builder(msgs, input, context)
        end
        return { messages = msgs }
      end
    end)
  end

  system_prompt = function(content)
    return function(msgs, input, context)
      table.insert(msgs, { role = 'system', content = content })
    end
  end

  selected_input = function(msgs, input, context)
    table.insert(msgs, { role = 'user', content = input })
  end

  go_prompt = system_prompt("You are an AI for programming in the Go language. Output only valid Go code, do not output markdown code blocks.")


  -- Model Builders

  build_model = function(model_builders)
    model = {}
    for i,builder in ipairs(model_builders) do
      model = builder(model)
    end
    return model
  end

  output_append            = builder(function(opt) opt.mode = mode.APPEND end)
  output_replace           = builder(function(opt) opt.mode = mode.REPLACE end)
  output_buffer            = builder(function(opt) opt.mode = mode.BUFFER end)
  output_insert            = builder(function(opt) opt.mode = mode.INSERT end)
  output_insert_or_replace = builder(function(opt) opt.mode = mode.INSERT_OR_REPLACE end)

  openai = builder(function(opt)
    opt.provider = openai_provider
    opt.params = {
      model = "gpt-4o",
    }
  end)

  claude = builder(function(opt)
    opt.provider = anthropic_provider
    opt.params = {
      model = "claud-3-5-sonnet-latest",
    }
    assert(opt.builder ~= nil, "claude builder must be placed after prompt builder")
    original_builder = opt.builder
    opt.builder = function (msgs, input, context)
      built = original_builder(msgs, input, context)
      if built.messages[1].role == 'system' then
        built.system = built.messages[1].content
        table.remove(built.messages, 1)
      end
      return built
    end
  end)

  library = {}
  library.gpt_append = build_model({
    openai,
    output_append,
    build_prompter({
      -- go_prompt,
      selected_input,
    })
  })
  library.gpt_buf = output_buffer(library.gpt_append)
  library.gpt_rep = output_replace(library.gpt_append)

  library.claude_append = build_model({
    output_append,
    build_prompter({
      -- go_prompt,
      selected_input,
    }),
    claude,
  })
  library.claude_buf = output_buffer(library.claude_append)
  library.claude_rep = output_replace(library.claude_append)

  require('model').setup({
    default_prompt = library.claude_append,
    prompts = library,
  })
end
