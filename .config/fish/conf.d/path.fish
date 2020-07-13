function add-to-path --argument-names path
  if test -d $path
    set -U fish_user_paths $fish_user_paths $path
  end
end

add-to-path ~/bin
add-to-path /snap/bin
add-to-path ~/.cargo/bin
add-to-path /opt/local/bin
add-to-path /opt/local/sbin
add-to-path /Applications/Postgres.app/Contents/Versions/latest/bin

