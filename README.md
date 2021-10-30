## Bootstrapping

To install a system, do this:

```bash
curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/amonks/setup/master/setup | bash -s
```

It will,

- clone this repository, if needed
- install xcode tools, if on darwin, if needed
- configure a package manager (macports or apt), if needed
- install fish shell
- run the fish function `setup` from ./config/fish/functions/setup.fish

## Installation

From fish, run `setup` at any time to configure the system. If
there's nothing to do, it exits quickly, so it's safe to rerun often.

`setup` will ask a few questions about what to install on this
machine, and save the results in ~/locals.fish. To change answers,
`rm ~/locals.fish`, open a new shell to unset any variables, then run
`setup` again.

## Configuration

Everything in the repo except for ./setup and ./README.md is just a
regular home-folder configuration file (eg dotfiles). Git for this
repo is globally aliased to `config`.

To commit a new file, eg,

```bash
config add ~/.config/fish/functions/new-function.fish
config commit -m "add new function"
config push
```

