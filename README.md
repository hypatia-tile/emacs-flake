# emacs-flake

Emacs for macOS, pinned here and offered to
[dotfiles-mac](https://github.com/hypatia-tile/dotfiles-mac) as a flake input.

## Status

**Decided, not yet wired.** `flake.nix` hands out Emacs 31.1 with the
`frame-transparency` patch, which is the only build found that gives working
transparency and blur on recent macOS. The machine's Emacs still comes from
Homebrew (`d12frosted/emacs-plus/emacs-plus@30`) and nothing in dotfiles-mac
consumes this flake yet.

Still missing before it can be: a binary cache and the CI that fills it, since
the patch costs 20m27s of local build per nixpkgs bump. The reasoning and every
measurement are in [docs/investigation.md](docs/investigation.md), including two
non-obvious prerequisites — this machine's Nix client is not a trusted user, and
`inputs.nixpkgs.follows` would defeat the cache.

## Why this exists

dotfiles-mac is Nix-first, with Homebrew kept as a declared exception lane for
GUI casks and for packages that genuinely need Homebrew's macOS-specific
builds (its ADR 0005). Emacs has been one of those exceptions since July 2026.

Two defects found in September 2026 made that exception look expensive: the
Homebrew Emacs stopped being able to natively compile anything for four weeks
without saying so, and its ahead-of-time compilation turns out to produce
almost nothing, so bundled Lisp is compiled at runtime instead. Both are
written up in the investigation, with what was measured kept apart from what
was only reasoned.

A dedicated repository buys control over the source revision and the build
flags, and it does not make the build any cheaper. There is now one concrete
thing that needs that control: the emacs-plus tap's `frame-transparency`
community patch, which exists for Emacs 31 only, targets the NS port, and
applies to nixpkgs' Emacs 31.1 source with no fuzz allowed. It is the only route
found to working transparency on recent macOS. Taking it costs the binary cache
— Emacs is compiled locally from then on — and that trade has not been decided.
The patch is not vendored here yet.

## Use

```sh
# The Cocoa (NS) build -- substituted from cache.nixos.org, nothing compiled.
nix build .#emacs-ns

# The macport build -- compiled locally, AOT pass included.
nix build .#emacs-macport
```

To try one without touching `~/.emacs.d`:

```sh
P=$(nix build --no-link --print-out-paths .#emacs-ns)
"$P/Applications/Emacs.app/Contents/MacOS/Emacs" -Q
```

`--no-link` keeps a `result` symlink -- and so a GC root -- out of the working
tree, which is what you want for a trial.

How dotfiles-mac would consume it, in the same idiom it already uses for
`neovim-nightly-overlay` and `rust-overlay`:

```nix
inputs.emacs-flake = {
  url = "github:hypatia-tile/emacs-flake";
  inputs.nixpkgs.follows = "nixpkgs";
};

# ... in the host's module
nixpkgs.overlays = [ inputs.emacs-flake.overlays.default ];
home.packages = [ pkgs.myEmacs ];
```

With `follows`, this flake's own `nixpkgs` input is bypassed and `pkgs.myEmacs`
is built from the consumer's pin. Only `overlays.default` matters on that path.

## The one knob

`flake.nix` decides what this flake hands out in a single line:

```nix
chosen = pkgs: pkgs.emacs;
```

`packages.default` and `overlays.default` both read it, so they cannot drift
apart. Changing which Emacs this repository stands for is that edit and nothing
else.

`flake.lock` is pinned to the same nixpkgs revision dotfiles-mac has, so a
standalone `nix build` here produces what dotfiles-mac would actually hand the
machine rather than something merely similar.

## Conventions

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/).
- Everything in the repository is written in English.
- Notes that hold in a repository you have never seen belong in
  [scrap](https://github.com/hypatia-tile/scrap), not here. This repository
  keeps the part that is specific to these machines and this decision.
