return function()
  local mode = require('model').mode
  local anthropic_provider = require('model.providers.anthropic')
  local openai_provider = require('model.providers.openai')

  require('model.providers.openai').initialize({
    model = 'gpt-4o'
  })

  build_model = function(...)
    model = {}
    for i,builder in ipairs(arg) do
      builder(model)
    end
    if model.builder ~= nil then
      model.builder = function(input, context)
        messages = {
          { role = 'user', content = input },
        }
      end
    end
    return model
  end

  prompt = function(...)
    prompt_builders = arg
    return function(opt)
      opt.builder = function(input, context)
        messages = {}
        for i,builder in ipairs(prompt_builders) do
          messages = builder(messages, input, context)
        end
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
  end

  default_prompt = build_model(
    output_replace,
    anthropic,
    prompt(
      system_prompt("You are an AI for programming in the Go language. Output only valid Go code, do not output markdown code blocks."),
      selected_input
    )
  )

  require('model').setup({
    default_prompt = default_prompt,
    prompts = {
      append = output_append(default_prompt),
      buffer = output_buffer(default_prompt),
    }
  })
end
