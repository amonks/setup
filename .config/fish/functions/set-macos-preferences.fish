function set-macos-preferences
  echo Setting macos preferences

  # Mouse speed
  defaults write 'Apple Global Domain' com.apple.trackpad.scaling 3

  # Keyboard Speed
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
  defaults write 'Apple Global Domain' InitialKeyRepeat 15
  defaults write 'Apple Global Domain' KeyRepeat 2

  # Disable autocorrect
  defaults write 'Apple Global Domain' NSAutomaticTextCompletionEnabled 0
  defaults write 'Apple Global Domain' NSAutomaticCapitalizationEnabled 0
  defaults write 'Apple Global Domain' NSAutomaticPeriodSubstitutionEnabled 0
  defaults write 'Apple Global Domain' NSAutomaticSpellingCorrectionEnabled 0
  defaults write 'Apple Global Domain' NSAutomaticTextCompletionEnabled 0

  # Enable smart quotes
  defaults write 'Apple Global Domain' NSAutomaticQuoteSubstitutionEnabled 1
  defaults write 'Apple Global Domain' NSAutomaticDashSubstitutionEnabled 1

  # Enable keyboard navigation
  defaults write 'Apple Global Domain' AppleKeyboardUIMode 2

  # Don't put the desktop on the desktop
  defaults write com.apple.finder CreateDesktop -bool FALSE

  # Dock on right
  defaults write com.apple.dock 'orientation' -string 'right'
  # Hide dock
  defaults write com.apple.dock "autohide" -bool "true"
  # Don't show recents
  defaults write com.apple.dock "show-recents" -bool "false"
end

