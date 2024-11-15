#!/usr/bin/env fish

if ! test -d $HOME/fonts
	mkdir $HOME/fonts
end

cp $HOME/Library/Fonts/* $HOME/fonts/

