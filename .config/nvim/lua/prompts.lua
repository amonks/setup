return function()
  local mode = require('model').mode
  local anthropic_provider = require('model.providers.anthropic')
  local openai_provider = require('model.providers.openai')

  require('model.providers.openai').initialize({
    model = 'gpt-4o'
  })

  build_model = function(model_builders)
    model = {}
    for i,builder in ipairs(model_builders) do
      builder(model)
    end
    return model
  end

  build_prompter = function(prompt_builders)
    return function(opt)
      opt.builder = function(input, context)
        msgs = {}
        for i,builder in ipairs(prompt_builders) do
          builder(msgs, input, context)
        end
        return { messages = msgs }
      end
    end
  end

  system_prompt = function(content)
    return function(msgs, input, context)
      table.insert(msgs, { role = 'system', content = content })
    end
  end

  selected_input = function(msgs, input, context)
    table.insert(msgs, { role = 'user', content = input })
  end

  output_append = function(opt) opt.mode = mode.APPEND end
  output_replace = function(opt) opt.mode = mode.REPLACE end
  output_buffer = function(opt) opt.mode = mode.BUFFER end
  output_insert = function(opt) opt.mode = mode.INSERT end
  output_insert_or_replace = function(opt) opt.mode = mode.INSERT_OR_REPLACE end

  openai = function(opt)
    opt.provider = openai_provider
    opt.params = {
      model = "gpt-4o",
    }
  end

  claude = function(opt)
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
  end

  go_prompt = system_prompt("You are an AI for programming in the Go language. Output only valid Go code, do not output markdown code blocks.")

  prompts = {}
  prompts.gpt_append = build_model({
    openai,
    output_append,
    build_prompter({
      go_prompt,
      selected_input,
    })
  })
  prompts.gpt_buf = output_buffer(prompts.gpt_append)
  prompts.gpt_rep = output_replace(prompts.gpt_append)

  prompts.claude_append = build_model({
    output_append,
    build_prompter({
      go_prompt,
      selected_input,
    }),
    claude,
  })
  prompts.claude_buf = output_buffer(prompts.claude_append)
  prompts.claude_rep = output_replace(prompts.claude_append)

  require('model').setup({
    default_prompt = prompts.claude_append,
    prompts = prompts,
  })
end
