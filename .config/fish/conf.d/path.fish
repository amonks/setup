debug-fish-init start (status -f)
  set -U fish_user_paths \
    ~/.opencode/bin \
    /Applications/Wireshark.app/Contents/MacOS \
    ~/.fly/bin \
    ~/bin \
    /usr/local/opt/ruby/bin \
    /usr/local/lib/ruby/gems/2.7.0/bin \
    /snap/bin \
    ~/.cargo/bin \
    /opt/local/bin \
    /opt/local/sbin \
    /Applications/Postgres.app/Contents/Versions/latest/bin \
    ~/.fzf/bin \
    /usr/local/go/bin \
    ~/.deno/bin/ \
    ~/android-platform-tools \
    ~/go/bin \
    ~/.emacs.d/bin \
    /Applications/Racket/bin \
    ~/Library/Python/3.8/bin \
    ~/Library/Python/3.9/bin \
    ~/.local/bin \
    /home/ajm/.claude/local/ \

  # sbin dirs: login sessions get these from login.conf (FreeBSD) or
  # /etc/paths (macOS), but non-interactive `ssh host cmd` shells don't.
  for dir in /sbin /usr/sbin /usr/local/sbin
    test -d $dir; and set -Ua fish_user_paths $dir
  end

debug-fish-init end (status -f)

