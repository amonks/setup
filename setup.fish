#!/usr/bin/env fish


set -q SETUP_MODE; or set SETUP_MODE "secondary"


set system_type unknown
if string match 'linux-gnu*' $OSTYPE 1>/dev/null
  if which yum 1>/dev/null
    set system_type yum
  end
else if string match 'darwin*' $OSTYPE 1>/dev/null
  set system_type macos
end

if test $system_type = unknown
  echo "Unsupported OS"
  exit 1
end

echo Setting up a $SETUP_MODE machine on $system_type



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

function with-default --argument-names secondary primary
  if test -n $secondary
    echo $secondary
  else
    echo $primary
  end
end

function install-package
  argparse 'n-name=' 'p-port=' 'y-yum=' -- $argv

  if test -z "$_flag_name"
    echo "required name not provided to install-package"
    return 1
  end

  if which $_flag_name 1>/dev/null
    return
  end

  echo Installing $_flag_name

  switch $system_type
    case macos
      sudo port install (with-default $_flag_name $_flag_port)
    case yum
      sudo yum -y install (with-default $_flag_name $_flag_yum)
  end
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

  

install-package --name fzf
install-package --name bash
install-package --name jq
install-package --name fd
install-package --name rg --port ripgrep
install-package --name autojump
install-package --name htop
install-package --name nvim --port neovim
install-package --name direnv
install-package --name tmux
install-package --name bat
install-package --name exa
install-package --name prettyping
install-package --name ncdu
install-package --name mtr
install-package --name mosh

if test $SETUP_MODE = primary
  setup_ssh_key
  install-package --name ledger
  install-package --name node --port nodejs14
  install_rust
end

if test $system_type = macos
  set_macos_preferences
  source ./macos_apps.fish
  install_macos_apps
end

