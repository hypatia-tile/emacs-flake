# patches

Patches applied to Emacs by `flake.nix`.

## Licensing

**These are not covered by this repository's MIT licence.** A patch here is a
diff against GNU Emacs source, so it is a derivative work of Emacs and carries
Emacs's own licence, **GPL-3.0-or-later**. The MIT `LICENSE` at the repository
root covers the Nix expressions and the prose, not this directory.

## frame-transparency-emacs-31.patch

Adds configurable frame transparency and background blur on macOS using CGS
APIs. Makes `alpha-background` take effect and adds two frame parameters,
`ns-background-blur` and `ns-alpha-elements`.

- Origin: the `d12frosted/homebrew-emacs-plus` tap, `community/patches/frame-transparency/emacs-31.patch`
- Maintainer: [aaratha](https://github.com/aaratha)
- Dated 2025-12-23; the tap records compatibility with Emacs 31 only
- Taken verbatim; nothing in this repository modifies it

It patches `src/frame.c`, `src/frame.h`, `src/macfont.m`, `src/nsfns.m`,
`src/nsterm.h` and `src/nsterm.m` — the NS (Cocoa) port, which is what
nixpkgs' `emacs` builds. It applies to nixpkgs' Emacs 31.1 source with no fuzz
allowed, and conflicts with none of the three patches nixpkgs applies. See
`docs/investigation.md` for the measurements, including what it costs.

Usage is in the upstream README next to the patch in that tap. In short:

```elisp
;; ns-background-blur must be in default-frame-alist: it sets the NSWindow
;; backing material at frame creation time, which is what blur needs.
(add-to-list 'default-frame-alist '(ns-background-blur . 30))
(add-to-list 'default-frame-alist '(ns-alpha-elements ns-alpha-all))
(add-to-list 'default-frame-alist '(alpha-background . 0.7))
```
