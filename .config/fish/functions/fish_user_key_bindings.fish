function fish_user_key_bindings
  fish_hybrid_key_bindings
  bind -M insert ! _bind_bang
  bind -M insert '$' _bind_dollar
end


if type fzf_key_bindings 1>/dev/null 2>&1
  fzf_key_bindings
end
