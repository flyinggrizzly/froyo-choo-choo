# froyo-choo-choo

This is a Rails app template backed by Nix and [bundix](https://github.com/inscapist/bundix) (specifically the fork
that supports multiple platform declarations, which is required for Sorbet).

It comes with:

- PostgreSQL, auto-installed and prepped by the flake
- Sorbet
- scripts for managing Ruby dependencies, since `bundle add <gem>` no longer works in Nix's readonly store

## Setup

```
sh <(curl -fsSL https://raw.githubusercontent.com/flyinggrizzly/froyo-choo-choo/main/install.sh) [<path>]
```

Run 👆 command, and follow any intructions (sets up the template in `.` if no `<path>` is provided).

## Dependency tooling

- `add-gem <gem>` adds a gem to your `Gemfile`, runs `bundle lock`, and then regenerates `gemset.nix`
- `update-gems` runs just `bundle lock` and regens `gemset.nix`. Useful if you've manually edited the `Gemfile`
- `bundle-add <gem>` runs `bundle add <gem> --skip-install` (used by `add-gem`)
- `bundle-lock` runs `bundle lock`
- `bundle-update` runs `bundle lock --update` (used by `update-gems`)
- `gemset-update` regenerates `gemset.nix` with `bundix -l`, and builds it out from `Gemfile.lock` (used by `add-gem` and `update-tems`)

If you want, you can also run the actual bundler commands, but don't forget the `--skip-install` flag.
