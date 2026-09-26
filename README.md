# emacs-flake

Emacs for macOS, pinned here and offered to
[dotfiles-mac](https://github.com/hypatia-tile/dotfiles-mac) as a flake input.

## Status

**Evaluation, not adopted.** The machine's Emacs still comes from Homebrew
(`d12frosted/emacs-plus/emacs-plus@30`), and nothing in dotfiles-mac consumes
this flake yet. The repository exists ahead of that decision on purpose: the
reasoning and the measurements are worth keeping whether or not the switch
happens. They are in [docs/investigation.md](docs/investigation.md).

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

Whether a dedicated repository is the right answer is itself an open question
the investigation states plainly: it buys control over the source revision and
the build flags, and it does not make the build any cheaper.

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
