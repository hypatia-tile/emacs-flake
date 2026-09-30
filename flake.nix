{
  description = "Emacs for macOS, pinned and built from source with Nix";

  # Tracks the same channel dotfiles-mac tracks, but flake.lock is this
  # flake's own pin: consumers must not `follows` it, or they build a
  # derivation CI never built and miss the binary cache (see README).
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
      transparency = ./patches/frame-transparency-emacs-31.patch;
      chosen =
        pkgs:
        pkgs.emacs.overrideAttrs (o: {
          patches = (o.patches or [ ]) ++ [ transparency ];
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

      # Whether the patch still applies with no fuzz, checked in seconds rather
      # than discovered twenty minutes into a build. stdenv's patchPhase runs
      # plain `patch -p1`, which accepts two lines of drift; for six C files of
      # the NS port, applying approximately is a patch that may compile and
      # still be wrong. nixpkgs' own patches go on first, as in the real build.
      # CI runs this before building; see issue #2.
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          frame-transparency = pkgs.stdenvNoCC.mkDerivation {
            name = "frame-transparency-applies-to-emacs-${pkgs.emacs.version}";
            inherit (pkgs.emacs) src patches;
            postPatch = ''
              if ! patch -p1 --batch --forward -F 0 < ${transparency}; then
                echo "error: frame-transparency does not apply to Emacs ${pkgs.emacs.version} without fuzz." >&2
                echo "Look for a newer one in d12frosted/homebrew-emacs-plus, community/patches/frame-transparency/." >&2
                exit 1
              fi
            '';
            dontConfigure = true;
            dontBuild = true;
            dontFixup = true;
            installPhase = "touch $out";
          };
        }
      );

      # Consumed by dotfiles-mac exactly like neovim-nightly-overlay and
      # rust-overlay already are: one entry in `inputs`, one line in
      # `nixpkgs.overlays`, then `pkgs.myEmacs` in `home.packages`.
      overlays.default = _final: prev: { myEmacs = chosen prev; };
    };
}
