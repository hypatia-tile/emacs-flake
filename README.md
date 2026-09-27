# emacs-flake

Emacs for macOS, pinned here and offered to
[dotfiles-mac](https://github.com/hypatia-tile/dotfiles-mac) as a flake input.

## Status

**Decided, not yet wired.** `flake.nix` hands out Emacs 31.1 with the
`frame-transparency` patch, which is the only build found that gives working
transparency and blur on recent macOS. CI builds it and pushes it to
[`hypatia-emacs.cachix.org`](https://app.cachix.org/cache/hypatia-emacs), so
consuming it costs a download rather than the twenty minutes it takes to compile.

The machine's Emacs still comes from Homebrew
(`d12frosted/emacs-plus/emacs-plus@30`) and nothing in dotfiles-mac consumes
this flake yet. The reasoning and every measurement are in
[docs/investigation.md](docs/investigation.md).

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

## Using the cache

Two things have to be true, and the first one catches people out.

**The cache must be declared where the daemon reads it.** Substituters are a
restricted setting, so unless your Nix client is a trusted user, a cache named
in `~/.config/nix/nix.conf`, on the command line, or in this flake's `nixConfig`
is *silently ignored*. Check with:

```sh
nix store info --json | grep trusted     # trusted = 0 means read on
```

On a Determinate install, `/etc/nix/nix.conf` belongs to Determinate and
`/etc/nix/nix.custom.conf` is the seam left for local additions:

```sh
sudo tee /etc/nix/nix.custom.conf >/dev/null <<'EOF'
extra-substituters = https://hypatia-emacs.cachix.org
extra-trusted-public-keys = hypatia-emacs.cachix.org-1:01hQJcXQlX0AFv1UpAL7v9zQNhoDT0bJzoNaAzABEzQ=
EOF
sudo launchctl kickstart -k system/org.nixos.nix-daemon
```

Declaring the one cache system-wide is narrower than adding yourself to
`trusted-users`, which would let any flake's `nixConfig` name a substituter.

Verify the client sees it, then verify it actually hits:

```sh
nix config show | grep -E '^(substituters|trusted-public-keys)'
nix build --dry-run .#default          # "will be fetched", not "will be built"
```

**Consume this flake with its own nixpkgs pin.** Not with
`inputs.nixpkgs.follows`:

```nix
inputs.emacs-flake.url = "github:hypatia-tile/emacs-flake";

# ... in the host's module
nixpkgs.overlays = [ inputs.emacs-flake.overlays.default ];
home.packages = [ pkgs.myEmacs ];
```

`follows` would build `pkgs.myEmacs` from the *consumer's* nixpkgs while CI
built against this flake's lock — a different derivation, so the cache would
miss every time and the twenty minutes would come back. The cost of not using
it is a second nixpkgs in the consumer's closure; the benefit, besides the
cache, is that Emacs stops moving every time the system's pin does.

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
