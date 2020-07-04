function wait_for_enter
  echo Press any key to continue
  read
end


function wait_for_volume --argument-names volume
  while ! test -d $volume
    sleep 0.5
  end
end


function with_dmg --argument-names filename mount_path cmd
  open $filename
  wait_for_volume $mount_path
  $cmd
  umount $mount_path
  rm $filename
end


function do_pkg --argument-names pkg
  open $pkg
  wait_for_enter
  if test -z (string match 'Volumes' $pkg)
    rm $pkg
  end
end


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


function install_1password
  if test -d "/Applications/1Password 7.app"
    return
  end

  echo "Installing 1Password"

  set onepassword_url "https://app-updates.agilebits.com/download/OPM7"
  curl --location $onepassword_url --output 1password.pkg
  do_pkg 1password.pkg
end


function install_karabiner
  if test -d "/Applications/Karabiner-Elements.app"
    return
  end

  echo "Installing Karabiner Elements"

  set karabiner_elements_version 12.10.0
  set karabiner_url "https://github.com/pqrs-org/Karabiner-Elements/releases/download/v$karabiner_elements_version/Karabiner-Elements-$karabiner_elements_version.dmg"
  set mount_path "/Volumes/Karabiner-Elements-$karabiner_elements_version"

  function __install_karabiner
    do_pkg "$mount_path/Karabiner-Elements.sparkle_guided.pkg"
  end

  curl --location $karabiner_url --output karabiner.dmg
  with_dmg karabiner.dmg "/Volumes/Karabiner-Elements-$karabiner_elements_version" __install_karabiner
end


function install_slack
  if test -d "/Applications/Slack.app"
    return
  end

  echo "Installing Slack"

  set volume /Volumes/Slack.app

  function __install_slack
    cp -r "$volume/Slack.app" "/Applications/Slack.app"
  end

  curl --location "https://slack.com/ssb/download-osx" --output slack.dmg
  with_dmg slack.dmg $volume __install_slack
end


function install_telegram
  if test -d "/Applications/Telegram.app"
    return
  end

  echo "Installing Telegram"

  set volume "/Volumes/Telegram"

  function __install_telegram
    cp -r "$volume/Telegram.app" "/Applications/Telegram.app"
  end

  curl --location "https://telegram.org/dl/macos" --output telegram.dmg
  with_dmg telegram.dmg $volume __install_telegram
end


function install_divvy
  if test -d "/Applications/Divvy.app"
    return
  end

  echo "Installing Divvy"
  
  curl --location "https://mizage.com/downloads/Divvy.zip" --output "divvy.zip"
  unzip "divvy.zip"
  mv "Divvy.app" "/Applications/Divvy.app"
  rm "divvy.zip"
end


function install_vscode
  if test -d "/Applications/Visual Studio Code.app"
    return
  end

  echo "Installing Visual Studio Code"

  curl --location "https://az764295.vo.msecnd.net/stable/cd9ea6488829f560dc949a8b2fb789f3cdc05f5d/VSCode-darwin-stable.zip" --output "vscode.zip"
  unzip "vscode.zip"
  mv "Visual Studio Code.app" "/Applications/Visual Studio Code.app"
  rm "vscode.zip"
end


function install_hey
  if test -d "/Applications/Hey.app"
    return
  end

  echo "Installing Hey"

  set volume "/Volumes/Hey 1.0.6"

  function __install_hey
    cp -r "$volume/Hey.app" "/Applications/Hey.app"
  end

  curl --location "https://hey-desktop.s3.amazonaws.com/HEY-1.0.6.dmg" --output "hey.dmg"
  with_dmg hey.dmg $volume __install_hey
end


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


function install_macos_apps
  install_1password
  install_karabiner
  install_slack
  install_telegram
  install_divvy
  install_vscode
  install_hey
end

