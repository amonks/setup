#!/usr/bin/env fish

function set_macos_preferences
  echo Setting macos preferences



  # Mouse

  defaults write 'Apple Global Domain' com.apple.trackpad.scaling 3


  # Keyboard

  ## Speed
  
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
  defaults write 'Apple Global Domain' InitialKeyRepeat 15
  defaults write 'Apple Global Domain' KeyRepeat 2

  ## Disable autocorrect

  defaults write 'Apple Global Domain' NSAutomaticTextCompletionEnabled 0
  defaults write 'Apple Global Domain' NSAutomaticCapitalizationEnabled 0
  defaults write 'Apple Global Domain' NSAutomaticPeriodSubstitutionEnabled 0
  defaults write 'Apple Global Domain' NSAutomaticSpellingCorrectionEnabled 0
  defaults write 'Apple Global Domain' NSAutomaticTextCompletionEnabled 0

  ## Smart quotes are ok tho

  defaults write 'Apple Global Domain' NSAutomaticQuoteSubstitutionEnabled 1
  defaults write 'Apple Global Domain' NSAutomaticDashSubstitutionEnabled 1

  ## Enable keyboard navigation

  defaults write 'Apple Global Domain' AppleKeyboardUIMode 2


  # Desktop

  defaults write com.apple.finder CreateDesktop -bool FALSE
end


function install_port --argument-names bin_name port_name
  if test -z "$port_name"
    set port_name $bin_name
  end

  if which $bin_name 1>/dev/null
    return
  end

  echo Installing $bin_name
  sudo port install $port_name
end


function setup_ssh_key
  if test -f ~/.ssh/id_rsa.pub
    return
  end

  echo Setting up ssh key

  ssh-keygen -t rsa -b 4096 -C "a@monks.co"
  eval "(ssh-agent -s)"
  ssh-add -K ~/.ssh/id_rsa
  open "https://github.com/settings/ssh/new"
  cat ~/.ssh/id_rsa.pub | pbcopy
  wait_for_enter
end

function install_rust
  if which rustc 1>/dev/null
    return
  end

  echo "Installing rust"

  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
end

  

set_macos_preferences
setup_ssh_key

# INSTALL PORTS
install_port fzf
install_port ledger
install_port node nodejs14
install_port bash
install_port jq
install_port fd
install_port rg ripgrep
install_port autojump
install_port htop
install_port nvim neovim
install_port direnv
install_port tmux
install_port bat
install_port exa
install_port prettyping
install_port ncdu
install_port mtr
install_port mosh

install_rust

source ./macos_apps.fish
install_macos_apps

