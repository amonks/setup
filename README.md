```bash
curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/amonks/setup/master/bootstrap.sh | bash -s
```

## what

- bootstrap sets up a bare git repo tracking ~ in ~/.cfg
- then it calls setup, which sets up the package manager and installs fish
- then it calls setup.fish which installs a bunch of shit

the other files are just regular dotfiles. if you make a new dotfile, you can, eg,

```bash
config add ~/.config/fish/functions/new-function.fish
config commit -m "add new function"
config push
```

## supported systems

- macos (with macports) 
- centos (with yum), and 
- ubuntu (with apt)

## careful tho

in interactive mode (so scripts still work fine) it sets up a bunch of shadowy aliases i'm used to (eg `ls` uses`exa`) that you may find annoying

