{
  description = "Emacs for macOS, pinned and built from source with Nix";

  # Tracks the same channel dotfiles-mac tracks, and flake.lock is pinned to
  # the same revision dotfiles-mac has, so `nix build` here produces exactly
  # what dotfiles-mac would hand the machine. When this flake is consumed with
  # `inputs.nixpkgs.follows = "nixpkgs"`, this input is bypassed entirely and
  # only the overlay below matters.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # The one knob. This decides what `packages.default` and the overlay hand
      # out, so the two cannot drift apart. See docs/investigation.md for what
      # each candidate costs.
      #
      # The Cocoa build plus the frame-transparency patch: the only combination
      # found that gives working transparency and blur on recent macOS. The
      # patch exists for Emacs 31 only and targets the NS port, so the macport
      # cannot carry it. Overriding drops the result out of cache.nixos.org --
      # measured at 20m27s to build on an M-series MacBook Air -- which is why
      # this repository publishes to a cache of its own.
      chosen =
        pkgs:
        pkgs.emacs.overrideAttrs (o: {
          patches = (o.patches or [ ]) ++ [ ./patches/frame-transparency-emacs-31.patch ];
        });
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = chosen pkgs;

          # GNU Emacs, Cocoa (NS) build. Substituted from cache.nixos.org in
          # full -- no local compilation.
          emacs-ns = pkgs.emacs;

          # Mitsuharu Yamamoto's macport. Adds the mac-* layer (tab groups,
          # Apple events, input-source control, appearance hooks) and is the
          # build that was trialled first. Not in the binary cache, so this
          # one is compiled locally, AOT pass included.
          emacs-macport = pkgs.emacs30-macport;
        }
      );

      # Consumed by dotfiles-mac exactly like neovim-nightly-overlay and
      # rust-overlay already are: one entry in `inputs`, one line in
      # `nixpkgs.overlays`, then `pkgs.myEmacs` in `home.packages`.
      overlays.default = _final: prev: { myEmacs = chosen prev; };
    };
}
