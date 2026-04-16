#!/usr/bin/env fish

if test -z "$machine_name"
  echo "set machine_name in ~/locals.fish"
  exit 1
end

if test -z "$machine_user"
  echo "set machine_user in ~/locals.fish"
  exit 1
end

if command -q fileproviderctl
  materialize-icloud ~
end

set -l rsync_excludes
for name in (backup-home-exclude-names)
    set -a rsync_excludes --exclude $name
end
for p in (backup-home-exclude-paths)
    set -a rsync_excludes --exclude /$p
end

rsync --archive --human-readable --delete --progress --ignore-errors \
  --include "/Library/Application?Support/*" \
  --include "/Library/Keychains/*" \
  --include "/Library/Preferences/*" \
  $rsync_excludes \
  ~/ "thor-syncer:/data/tank/mirror/$machine_name/$machine_user"
