#!/usr/bin/env bash

cd "$HOME" || exit

if test -d "$HOME/.cfg" ; then
  echo It looks like you have already set up.
  exit 1
fi

git clone --bare https://github.com/amonks/setup.git "$HOME/.cfg"
git --git-dir="$HOME/.cfg/" --work-tree="$HOME" checkout

./setup

