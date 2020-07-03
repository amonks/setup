#!/usr/bin/env bash

cd $HOME

git clone --bare git@github.com:amonks/setup-samsara-devbox.git $HOME/.cfg
git --git-dir=$HOME/.cfg/ --work-tree=$HOME checkout

./setup

