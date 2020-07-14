function install-rust
  if is-installed rustc
    return
  end

  echo "Installing rust"

  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
end

