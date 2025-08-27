if test -d /Applications/Xcode.app
  set -x SDKROOT (xcrun --sdk macosx --show-sdk-path)
  set -x LIBRARY_PATH "$LIBRARY_PATH" "$SDKROOT/usr/lib"
end

if test -d /Applications/Android\ Studio.app/Contents/jbr/Contents/Home
  set -x JAVA_HOME '/Library/Java/JavaVirtualMachines/jdk-21-macports.jdk/Contents/Home'
end

