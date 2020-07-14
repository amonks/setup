function update-package-manager
  echo Updating package manager

  if test (system-type) = "apt"
    sudo add-apt-repository ppa:neovim-ppa/unstable -y
    sudo apt-add-repository ppa:fish-shell/release-3 -y

    sudo apt-get update -y
    sudo apt-get upgrade -y
    sudo apt-get dist-upgrade -y
  else if test (system-type) = "macos"
    sudo port selfupdate
  end
end

