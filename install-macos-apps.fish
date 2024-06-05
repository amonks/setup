function with_dmg --argument-names filename mount_path cmd
  open $filename
  wait-for-volume $mount_path
  $cmd
  umount $mount_path
  rm $filename
end


function do_pkg --argument-names pkg
  open $pkg
  wait-for-enter
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

  set onepassword_url "https://downloads.1password.com/mac/1Password.zip"
  curl --location $onepassword_url --output 1password.zip
  tar xzf 1password.zip
  do_pkg '1Password Installer.pkg'
end


function install_karabiner
  if test -d "/Applications/Karabiner-Elements.app"
    return
  end

  echo "Installing Karabiner Elements"

  set karabiner_elements_version 13.5.0
  set karabiner_url "https://github.com/pqrs-org/Karabiner-Elements/releases/download/v$karabiner_elements_version/Karabiner-Elements-$karabiner_elements_version.dmg"
  set mount_path "/Volumes/Karabiner-Elements-$karabiner_elements_version"

  function __install_karabiner
    do_pkg "$mount_path/Karabiner-Elements.sparkle_guided.pkg"
  end

  curl --location $karabiner_url --output karabiner.dmg
  with_dmg karabiner.dmg "/Volumes/Karabiner-Elements-$karabiner_elements_version" __install_karabiner
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


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


install_1password
install_karabiner
install_telegram
install_divvy

