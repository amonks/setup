#!/usr/bin/env fish

if test -z "$machine_name"
	echo "set machine_name in ~/locals.fish"
end

if test -z "$machine_user"
	echo "set machine_user in ~/locals.fish"
end

rsync -ha --progress \
  --include "/Library/Keychains/*" \
  --include "/Library/Application?Support/*" \
  --include "/Library/Preferences/*" \
  --exclude "/Library/*" \
  --exclude ".DS_Store" \
  --exclude ".viminfo" \
  --exclude ".localized" \
  --exclude ".Trash" \
  ~/ thor-syncer:/mypool/data/mirror/$machine_name/$machine_user

