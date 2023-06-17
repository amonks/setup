function toggle-night-mode
  set enabled false
  if grep 'light mode' ~/.config/alacritty/alacritty.yml
    set enabled true
  end
  delete-after ~/.config/alacritty/alacritty.yml FG_SET
  delete-after ~/.config/alacritty/alacritty.yml BG_SET
  if test $enabled = true
    insert-after ~/.config/alacritty/alacritty.yml FG_SET "    foreground: '0xE8DCB7' # dark mode"
    insert-after ~/.config/alacritty/alacritty.yml BG_SET "    background: '0x000000' # dark mode"
  else
    insert-after ~/.config/alacritty/alacritty.yml FG_SET "    foreground: '0x5B6970' # light mode"
    insert-after ~/.config/alacritty/alacritty.yml BG_SET "    background: '0xFCF6E5' # light mode"
  end
end



