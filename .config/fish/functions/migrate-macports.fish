function migrate-macports
  echo "Migrating macports."

  echo "First, uninstalling ports."
  sudo port -f uninstall installed
  sudo rm -rf /opt/local/var/macports/build/*
  echo
  echo "Done. Now installing new macports version."
  echo
  echo "Go here and find the new pkg url:"
  echo "https://www.macports.org/install.php"
  open "https://www.macports.org/install.php"
  read -p "url? " url
  curl --location $url --output macports.pkg
  open macports.pkg
  wait-for-enter
  rm macports.pkg
  echo 
  echo "Done. Now run ~/setup to reinstall ports."
end

