# emacs-flake

Emacs for macOS, pinned here and offered to
[dotfiles-mac](https://github.com/hypatia-tile/dotfiles-mac) as a flake input.

## Status

**In use.** `flake.nix` hands out Emacs 31.1 with the `frame-transparency`
patch, which is the only build found that gives working transparency and blur on
recent macOS. CI builds it and pushes it to
[`hypatia-emacs.cachix.org`](https://app.cachix.org/cache/hypatia-emacs), so
consuming it costs a download rather than the twenty minutes it takes to compile.

dotfiles-mac has consumed it since 2026-09-27 (its ADR 0031), and `emacs-plus@30`
has left the machine. The reasoning and every measurement are in
[docs/investigation.md](docs/investigation.md); what is still open is in the
[issues](https://github.com/hypatia-tile/emacs-flake/issues).

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
found to working transparency on recent macOS. Taking it drops the build out of
`cache.nixos.org`, so this repository publishes to a cache of its own and CI
does the compiling. The patch is vendored under [patches/](patches/), with its
licence and origin.

## Use

```sh
# What this flake hands out: the Cocoa build plus frame-transparency.
# Fetched from hypatia-emacs.cachix.org once the cache is declared (below).
nix build .#default

# The Cocoa (NS) build, unpatched -- substituted from cache.nixos.org.
nix build .#emacs-ns

# The macport build -- compiled locally, AOT pass included.
nix build .#emacs-macport
```

To try one without touching `~/.emacs.d`:

```sh
P=$(nix build --no-link --print-out-paths .#default)
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

It has to go in a file the running Nix actually reads, which is **not**
`/etc/nix/nix.custom.conf` unless you are on Determinate Nix. That file is a
Determinate feature; upstream Nix ignores it, silently. Check which you have:

```sh
nix --version        # "nix (Nix) 2.31.4" is upstream; Determinate says so
```

On upstream Nix the only system config is `/etc/nix/nix.conf`. Keeping local
additions in their own file and including it leaves that file alone afterwards,
and matches where Determinate would want them if it is ever installed:

```sh
sudo tee /etc/nix/nix.custom.conf >/dev/null <<'EOF'
extra-substituters = https://hypatia-emacs.cachix.org
extra-trusted-public-keys = hypatia-emacs.cachix.org-1:01hQJcXQlX0AFv1UpAL7v9zQNhoDT0bJzoNaAzABEzQ=
EOF
sudo tee -a /etc/nix/nix.conf >/dev/null <<'EOF'
!include /etc/nix/nix.custom.conf
EOF
sudo launchctl kickstart -k system/org.nixos.nix-daemon
```

`!include` does not fail when the file is missing. The daemon is what
substitutes, so it has to be restarted to read either file.

**`/etc/nix/nix.conf` is installer-owned, so a Nix upgrade can overwrite it.**
If the cache ever stops being used for no apparent reason, check that the
`!include` line is still there before looking anywhere else.

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

`flake.nix` decides what this flake hands out in one place:

```nix
chosen =
  pkgs:
  pkgs.emacs.overrideAttrs (o: {
    patches = (o.patches or [ ]) ++ [ ./patches/frame-transparency-emacs-31.patch ];
  });
```

`packages.default` and `overlays.default` both read it, so they cannot drift
apart. Changing which Emacs this repository stands for is that edit and nothing
else.

`flake.lock` is this flake's own pin, and it is what the machine actually runs:
dotfiles-mac does not `follows` it, so a standalone `nix build` here produces
the same path CI pushed and the machine fetched. Moving it is what moves Emacs;
the system's nixpkgs bumps no longer do.

## Conventions

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/).
- Everything in the repository is written in English.
- Notes that hold in a repository you have never seen belong in
  [scrap](https://github.com/hypatia-tile/scrap), not here. This repository
  keeps the part that is specific to these machines and this decision.
