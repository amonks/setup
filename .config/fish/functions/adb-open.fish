function adb-open --argument-names app
  adb shell monkey -p $app -c android.intent.category.LAUNCHER 1
end
