#!/usr/bin/env fish

function wait_for_enter
	echo Press any key to continue
	read
end

function wait_for_volume --argument-names volume
	while ! test -d $volume
		sleep 0.5
	end
end

function set_preferences
	echo Setting preferences



	# Mouse

	defaults write 'Apple Global Domain' com.apple.trackpad.scaling 3


	# Keyboard

	## Speed
	
	defaults write 'Apple Global Domain' InitialKeyRepeat 15
	defaults write 'Apple Global Domain' KeyRepeat 2

	## Disable autocorrect

	defaults write 'Apple Global Domain' NSAutomaticTextCompletionEnabled 0
	defaults write 'Apple Global Domain' NSAutomaticCapitalizationEnabled 0
	defaults write 'Apple Global Domain' NSAutomaticPeriodSubstitutionEnabled 0
	defaults write 'Apple Global Domain' NSAutomaticSpellingCorrectionEnabled 0
	defaults write 'Apple Global Domain' NSAutomaticTextCompletionEnabled 0

	## Smart quotes are ok tho

	defaults write 'Apple Global Domain' NSAutomaticQuoteSubstitutionEnabled 1
	defaults write 'Apple Global Domain' NSAutomaticDashSubstitutionEnabled 1

	## Enable keyboard navigation

	defaults write 'Apple Global Domain' AppleKeyboardUIMode 2


	# Desktop

	defaults write com.apple.finder CreateDesktop -bool FALSE

end


function install_1password
	if test -d /Applications/1Password\ 7.app
		return
	end

	echo Installing 1Password

	set onepassword_url https://app-updates.agilebits.com/download/OPM7
	curl --location $onepassword_url --output 1password.pkg
	open 1password.pkg
	wait_for_enter
	rm 1password.pkg
end

function install_karabiner
	if test -d /Applications/Karabiner-Elements.app
		return
	end

	echo Installing Karabiner Elements

	set karabiner_elements_version 12.10.0
	set karabiner_url https://github.com/pqrs-org/Karabiner-Elements/releases/download/v$karabiner_elements_version/Karabiner-Elements-$karabiner_elements_version.dmg
	curl --location $karabiner_url --output karabiner.dmg
	open karabiner.dmg
	set mount_path /Volumes/Karabiner-Elements-$karabiner_elements_version
	wait_for_volume $mount_path
	open $mount_path/Karabiner-Elements.sparkle_guided.pkg
	wait_for_enter
	umount $mount_path
	rm karabiner.dmg
end

function install_port --argument-names bin_name port_name
	if test -z "$port_name"
		set port_name $bin_name
	end

	if which $bin_name 1>/dev/null
		return
	end

	echo Installing $bin_name
	sudo port install $port_name
end

function install_slack
	if test -d /Applications/Slack.app
		return
	end

	echo Installing slack

	curl --location https://slack.com/ssb/download-osx --output slack.dmg
	open slack.dmg
	set volume /Volumes/Slack.app
	wait_for_volume $volume
	cp -r $volume/Slack.app /Applications/Slack.app
	umount $volume
	rm slack.dmg
end

function install_telegram
	if test -d /Applications/Telegram.app
		return
	end

	echo Installing Telegram

	curl --location https://telegram.org/dl/macos --output telegram.dmg
	open telegram.dmg
	set volume /Volumes/Telegram
	wait_for_volume $volume
	cp -r $volume/Telegram.app /Applications/Telegram.app
	umount $volume
	rm telegram.dmg
end

function install_divvy
	if test -d /Applications/Divvy.app
		return
	end

	echo Installing Divvy
	
	curl --location https://mizage.com/downloads/Divvy.zip --output divvy.zip
	unzip divvy.zip
	mv Divvy.app /Applications/Divvy.app
	rm divvy.zip
end

function setup_ssh_key
	if test -f ~/.ssh/id_rsa.pub
		return
	end

	echo Setting up ssh key

	ssh-keygen -t rsa -b 4096 -C "a@monks.co"
	eval "(ssh-agent -s)"
	ssh-add -K ~/.ssh/id_rsa
	open "https://github.com/settings/ssh/new"
	cat ~/.ssh/id_rsa.pub | pbcopy
	wait_for_enter
end

function install_vscode
	if test -d /Applications/Visual\ Studio\ Code.app
		return
	end

	echo Installing Visual Studio Code

	curl --location https://az764295.vo.msecnd.net/stable/cd9ea6488829f560dc949a8b2fb789f3cdc05f5d/VSCode-darwin-stable.zip --output vscode.zip
	unzip vscode.zip
	mv Visual\ Studio\ Code.app /Applications/Visual\ Studio\ Code.app
	rm vscode.zip
end

function install_hey
	if test -d /Applications/Hey.app
		return
	end

	echo Installing Hey

	curl --location https://hey-desktop.s3.amazonaws.com/HEY-1.0.6.dmg --output hey.dmg
	open hey.dmg
	set volume "/Volumes/Hey 1.0.6"
	wait_for_volume "$volume"
	cp -r "$volume/Hey.app" /Applications/Hey.app
	umount "$volume"
	rm hey.dmg
end

	

set_preferences
install_1password
install_karabiner
install_slack
install_port jq
install_port fd
install_port rg ripgrep
install_port autojump
install_port htop
install_port nvim neovim
install_telegram
install_divvy
setup_ssh_key
install_vscode
install_hey
install_port direnv
install_port tmux
install_port bat
install_port exa
install_port prettyping
install_port ncdu
install_port mtr

