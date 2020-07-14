function set-macos-preferences
  echo Setting macos preferences



  # Mouse

  defaults write 'Apple Global Domain' com.apple.trackpad.scaling 3


  # Keyboard

  ## Speed
  
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
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

