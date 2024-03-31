-- live grep
nmap("<C-f>", function()
  local fzf_run = vim.fn["fzf#run"]
  local fzf_wrp = vim.fn["fzf#wrap"]
  rg_prefix="rg --column --line-number --no-heading --color=always --smart-case"
  fzf_run(fzf_wrp({
    source = "echo ''",
    options = {
      "--bind", "start:reload:"..rg_prefix.." ''",
      "--bind", "change:reload:"..rg_prefix.." {q} || true",
      "--ansi", "--disabled",
      "--layout=reverse",
    },
    sink = function(item)
      print("hello", item)
      local firstColonIndex, _ = string.find(item, ":")
      local filepath = string.sub(item, 1, firstColonIndex-1)

      local secondColonIndex, _ = string.find(item, ":", firstColonIndex+1)
      local lineno = string.sub(item, firstColonIndex+1, secondColonIndex-1)

      vim.cmd("e +"..lineno.." "..filepath)
    end,
  }))
end)

-- ctrlp
nmap("<C-p>", function()
  local fzf_run = vim.fn["fzf#run"]
  local fzf_wrp = vim.fn["fzf#wrap"]
  fd = "fd --type=f --hidden --ignore --exclude=.git"
  fzf_run(fzf_wrp({
    source = "echo ''",
    options = {
      "--bind", "start:reload:"..fd,
      "--ansi",
      "--layout=reverse",
    },
    sink = "e"
  }))
end)


