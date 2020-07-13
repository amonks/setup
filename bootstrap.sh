#!/usr/bin/env bash

set -ex

cd "$HOME" || exit

if ! test -d "$HOME/.cfg" ; then
  git clone --bare https://github.com/amonks/setup.git "$HOME/.cfg"
fi

git --git-dir="$HOME/.cfg/" --work-tree="$HOME" checkout
git --git-dir="$HOME/.cfg/" --work-tree="$HOME" pull --force

./setup

