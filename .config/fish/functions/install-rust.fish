function install-rust
  if which rustc 1>/dev/null
    return
  end

  echo "Installing rust"

  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
end

