#!/usr/bin/env fish

if test -z "$machine_name"
  echo "set machine_name in ~/locals.fish"
  exit 1
end

if test -z "$machine_user"
  echo "set machine_user in ~/locals.fish"
  exit 1
end

if which fileproviderctl
  materialize-icloud ~
end

rsync --archive --human-readable --delete --progress --ignore-errors \
  --include "/Library/Application?Support/*" \
  --include "/Library/Keychains/*" \
  --include "/Library/Preferences/*" \
  --exclude ".DS_Store" \
  --exclude ".Trash" \
  --exclude ".localized" \
  --exclude ".viminfo" \
  --exclude "/.cache" \
  --exclude "/.local/share/autojump" \
  --exclude "/.zfs" \
  --exclude "/AppleInternal" \
  --exclude "/Library" \
  --exclude "/Library/Fonts" \
  --exclude "/Music/Library-v0" \
  --exclude "/go/pkg" \
  --exclude "/mnt" \
  --exclude "tailscaled.state" \
  ~/ "thor-syncer:/data/tank/mirror/$machine_name/$machine_user"

