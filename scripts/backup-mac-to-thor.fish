#!/usr/bin/env fish

if test -z "$machine_name"
  echo "set machine_name in ~/locals.fish"
  exit 1
end

if test -z "$machine_user"
  echo "set machine_user in ~/locals.fish"
  exit 1
end

rsync --archive --human-readable --delete --progress \
  --include "/Library/Application?Support/*" \
  --include "/Library/Keychains/*" \
  --include "/Library/Preferences/*" \
  --exclude ".DS_Store" \
  --exclude ".Trash" \
  --exclude ".localized" \
  --exclude ".viminfo" \
  --exclude "/.zfs" \
  --exclude "/AppleInternal" \
  --exclude "/Library" \
  --exclude "/Library/Fonts" \
  --exclude "/Music/Library-v0" \
  --exclude "/mnt" \
  --exclude "tailscaled.state" \
  ~/ "thor-syncer:/mypool/tank/mirror/$machine_name/$machine_user"

