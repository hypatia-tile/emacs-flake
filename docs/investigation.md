# Investigation: how Emacs is built on this machine, and why this repo exists

Recorded 2026-09-26, from one session's work on `Kazukis-MacBook-Air`
(Darwin 27.0.0, aarch64-darwin).

Measurements were taken on that machine unless a section says otherwise. Where
a claim was reasoned rather than measured, it says so and names what would
settle it. That line is the point of the document: a record that hides its
uncertain parts cannot be trusted on its certain ones.

The general, machine-independent halves of what was learned live in
[scrap](https://github.com/hypatia-tile/scrap) instead, under `emacs/`. This
document keeps the part that is about these machines and this decision.

## Motivation

dotfiles-mac is Nix-first. Its ADR 0005 reserves Homebrew for GUI casks and for
packages that genuinely need Homebrew's macOS-specific builds, and everything
brew-managed is declared in the nix-darwin `homebrew` module with
`onActivation.cleanup = "uninstall"`.

Emacs has been one of those exceptions since 2026-07-28, when
`d12frosted/emacs-plus/emacs-plus@30` replaced the `emacs-app` cask. The reason
recorded at the time was simply that a native build was wanted and Homebrew was
the easiest route to one.

Two defects found in September 2026 made that exception look expensive. Neither
is a reason on its own to move, but together they are what prompted asking the
question, and the answer is worth writing down whichever way it goes.

There is a second motivation, independent of the outcome: the reasoning should
outlive the session that produced it. The July attempt at a Nix Emacs left no
trace in any repository — see below — and that is exactly the loss this
repository exists to prevent.

## Defect 1: native compilation was silently broken for four weeks

The general mechanism is in
[scrap: Emacs native compilation needs gcc, not just libgccjit](https://github.com/hypatia-tile/scrap/blob/main/emacs/native-compilation-libgccjit.md).
What is specific to this machine:

`gcc` had been uninstalled — the fallout of dotfiles-mac #57, where a
`brew bundle cleanup` run against a Brewfile naming `emacs-plus@30` without its
tap prefix walked none of the formula's dependencies and removed its runtime
tree. The fully-qualified name fixed cleanup, but nothing restores a dependency
deleted out from under an already-installed formula.

Observed state before the repair:

- `brew list --versions gcc` — nothing.
- 33 `.eln.tmp` in `~/.emacs.d/eln-cache/30.2-b4b3785a/`, 14 of them
  `apheleia`'s, from a package installed 2026-09-24.
- No `.eln` newer than 2026-08-28.
- `(native-comp-available-p)` still `t`; every package still working.

Repaired with `brew install gcc` (16.2.0, matching libgccjit 16.2.0). The
declared dependency closure of dotfiles-mac's Brewfile is now complete: 62
formulae, all installed, with `readline` accounted for as `sqlite`'s declared
dependency. dotfiles-mac #146 carries the follow-up, including whether
activation should check that a declared formula's closure is intact.

## Defect 2: emacs-plus ships an almost empty AOT tree

`emacs-plus@30` is built from source (`poured_from_bottle = False`) with
`--with-native-compilation=aot`, confirmed in the running Emacs's
`system-configuration-options`. Its bundled `native-lisp` nevertheless holds
**one** `.eln`, `preloaded/ns-win.eln`, installed in two locations:

| | bundled `.eln` |
| --- | --- |
| `emacs-plus@30` 30.2 (Homebrew, source build, `aot`) | 2 (one file, twice) |
| `emacs-mac-macport-30.2.50` (Nix) | 3098 |

The consequence lands in the user's cache. Of 437 `.eln` in
`~/.emacs.d/eln-cache/30.2-b4b3785a/`:

- 10 trampolines — normal at runtime even with a complete AOT tree;
- **339 bundled Emacs Lisp files** — compiled at runtime because the Cellar has
  none of them;
- 88 package or own Lisp — the legitimate residents of that directory.

This also explains why `cal-iso`, `diary-lib` and `misc` appeared among the
failed `.eln.tmp` during the gcc outage: core Lisp was being compiled at
runtime, so the outage reached it.

**The cause was not determined.** `gcc` *was* installed when Emacs was built:
the binary carries `LC_RPATH /opt/homebrew/lib/gcc/16`, and the formula derives
that path from `Formula["gcc"].any_installed_version` at build time. So the
missing-gcc story does not explain this one.

One hypothesis: a gcc/libgccjit **major mismatch** at build time (gcc 16 with
libgccjit 15) would make every AOT unit fail on `libemutls_w.a`, exactly as
observed during the outage. Counter-evidence: `preloaded/ns-win.eln` was
produced, and it should have failed too. July's libgccjit version cannot be
recovered — only 16.2.0 is in the Cellar, its receipt dated 2026-09-05 — and no
emacs-plus build log survives. A rebuild with `--verbose` and the log kept
would settle it; the check afterwards is one command:

```sh
find /opt/homebrew/Cellar/emacs-plus@30 -name '*.eln' | wc -l   # expect ~3000
```

That rebuild was deliberately not run: it is long, a failure leaves the machine
without an Emacs, and it is wasted work if Emacs moves to Nix anyway.

## The July attempt, and why it was abandoned

`nix-store --query --roots` puts `emacs-mac-macport-30.2.50` in system
generation 88, which predates 2026-07-25. No commit in dotfiles-mac mentions
`macport` or `emacs-mac` — `git log -S` over the whole history finds nothing —
so it was an **uncommitted experiment**, applied to the machine and dropped
days before emacs-plus landed on 2026-07-28.

The owner's recollection: many things were broken, and the GUI in particular did
not work. Homebrew was the easiest route to a working native build.

Nothing more specific survives, which is the gap this repository closes.

## Re-trial, 2026-09-26: that blocker does not reproduce

The July build is still in the store, so it could be tried at no cost. Launched
with `-Q`, with `~/.emacs.d` untouched:

| | result |
| --- | --- |
| Window opens | yes |
| Japanese font | correct, no tofu |
| macSKK `C-j` | behaves as configured; releasing 直接入力 types Japanese |
| Transparency | does not work |
| xwidgets | compiled in (`xwidget-internal` → `t`) |

`CFBundleIdentifier` is `org.gnu.Emacs` for both the Nix and Homebrew bundles,
which is what macSKK keys its 直接入力 list on (dotfiles-mac ADR 0029), so that
hand-made configuration carries over.

The NS build, `emacs` 31.1, was trialled the same way the next day and passed
the same checks: window, Japanese font, xwidgets. `C-j` reaching
`eval-print-last-sexp` there is not a defect — `*scratch*` under `-Q` is
`lisp-interaction-mode`, where that is the standard binding in every Emacs, and
this configuration puts ddskk on `C-x C-j` rather than on `C-j`. That macSKK
handed the chord to Emacs at all is the outcome ADR 0029 wants.

Transparency does not work on either Nix build, nor on the Homebrew one, so it
separates none of them. It turns out not to be a property of the build at all;
see the next section.

The configuration needs nothing from the macport. `init.el` uses no `mac-*` or
`ns-*` function; its only platform test is `(memq window-system '(mac ns x))`,
which covers both ports. So the `mac-*` layer is not a reason to prefer the
macport.

## Candidates, and what each costs

From the nixpkgs revision dotfiles-mac has pinned
(`34ca302a9572963c02e385c056be37c85ff51b77`, 2026-09-24):

| attribute | version | `nix build --dry-run` |
| --- | --- | --- |
| `emacs` (Cocoa/NS) | **31.1** | 13 paths fetched, **0 built** |
| `emacs30-macport` | 30.2.50 | 59 fetched, **2 built**: `native-comp-driver-options-30.patch` and `emacs-mac-macport-30.2.50` itself |
| `emacs30` | — | gone: *"superseded by 'emacs' on august 2026"* |

So adopting the macport means compiling Emacs locally, AOT pass included, on
every nixpkgs bump that changes its inputs. The NS build is a download.

`emacs` 31.1 configure flags:

```
--with-ns --with-modules --with-native-compilation --with-tree-sitter
--with-xwidgets --with-mailutils --with-toolkit-scroll-bars
--without-imagemagick --without-dbus
```

What the macport adds over it is the `mac-*` layer — roughly 250 functions and
variables: tab groups, Apple events, input-source control, appearance-change
hooks, `mac-do-applescript`, frame restacking. Native compilation, tree-sitter,
xwidgets and dynamic modules are in both.

One thing to get right, because it was first recorded wrongly: the Flymake
behaviour that cost a day on the NixOS machine — every backend disabled as
untrusted content — is **not** an Emacs 31 change. Upstream gates only
`elisp-flymake-byte-compile`, and neither `flymake-always-safe` nor a
`trusted-content` check in `flymake.el` exists anywhere in the Emacs 31.1 source
nixpkgs builds from. Both come from nixpkgs' own `CVE-2024-53920.patch`.

That matters here in both directions: choosing *any* nixpkgs Emacs brings the
gate, and choosing a Homebrew `emacs-plus@31` would not. The escape hatch is
already committed in the Emacs config repo (`hypatia-tile/emacs-mac`, 4c4e1c3,
corrected in 0109a01), and it is inert where the patch is absent, so it costs
nothing either way.

## What a dedicated repository buys, and what it does not

**Buys:** control over the source revision and the build flags, in one place,
with the reasoning recorded next to it. If the answer turns out to need a patch
or a revision nixpkgs does not carry, this is where that lives.

**Does not buy:** a cheaper build. Overriding anything changes the derivation
hash and drops the result out of `cache.nixos.org`, so the local compile happens
on every bump, not only when Emacs changes. A dedicated repository makes that
cost *deliberate*; it does not remove it. Removing it would take a binary cache
of one's own.

That was written expecting the first outcome below, and the second one is what
happened.

**The override exists, and it is transparency.** The emacs-plus tap carries a
community patch, `frame-transparency` (maintainer `aaratha`, 2025-12-23),
described as adding "configurable frame transparency and background blur support
on macOS using CGS APIs". It makes `alpha-background` take effect and adds
`ns-background-blur` and `ns-alpha-elements` frame parameters. Two things about
it decide the whole question:

- its `compatibility.emacs_versions` is `["31"]`, and the directory holds only
  `emacs-31.patch` — so the macport, at 30.2.50, cannot have it at all;
- it patches `src/frame.c`, `src/frame.h`, `src/macfont.m`, `src/nsfns.m`,
  `src/nsterm.h` and `src/nsterm.m` — the **NS port**, which is exactly what
  nixpkgs' `emacs` is.

It applies to nixpkgs' Emacs 31.1 source with no fuzz allowed:

```
$ patch -p1 --dry-run -F 0 --directory=<emacs-31.1-src> < frame-transparency/emacs-31.patch
patching file 'src/frame.c'
patching file 'src/frame.h'
patching file 'src/macfont.m'
patching file 'src/nsfns.m'
patching file 'src/nsterm.h'
patching file 'src/nsterm.m'
exit: 0
```

None of nixpkgs' three patches (`CVE-2024-53920.patch`,
`load-the-early-default-library-after-early-init.el.patch`,
`native-comp-driver-options-30.patch`) touches any of those six files, so the
order they are applied in does not matter.

**It renders.** Built and confirmed on 2026-09-27. The build took **20m27s**
wall clock on this machine (M-series MacBook Air, `exit 0`), and the resulting
Emacs carries the new frame parameters where the stock one does not:

| | `ns-background-blur` | `ns-alpha-elements` | `ns-alpha-all` |
| --- | --- | --- | --- |
| stock `emacs` 31.1 | nil | nil | nil |
| the same plus this patch | t | t | t |

(`intern-soft` on each name; the patch defines them in C, so their presence is
evidence the patch reached the binary.) The AOT tree is complete either way,
3137 `.eln`. A GUI frame with `alpha-background 0.7` and `ns-background-blur 30`
in `default-frame-alist` shows transparency and blur — the first build on this
machine to do so, after four Emacsen that did not.

So the repository is not merely a record: `emacs` 31.1 plus this patch is the
only route found to transparency, and it keeps native compilation with a
complete AOT tree and a GUI that passes the trial. The patch is vendored under
`patches/` and `flake.nix` hands it out.

The price is 20m27s per rebuild, paid whenever the pinned nixpkgs moves, not
only when Emacs changes. That was judged worth paying, with the cost moved off
this machine rather than accepted: the repository publishes to a binary cache of
its own and CI does the building. What that takes is the next section.

## What publishing to a cache takes here

Two things about this machine are not obvious and decide the shape.

**The Nix client is not trusted.**

```
$ nix store info --json
trusted = 0
url = daemon
```

Nix is installed by the Determinate installer, so it runs multi-user through a
daemon, and `/etc/nix/nix.conf` carries only `build-users-group = nixbld` — no
`trusted-users`. Substituters are a restricted setting, so a cache declared in
`~/.config/nix/nix.conf`, on the command line with `--option`, or in a flake's
`nixConfig` is **silently ignored** for this user. The cache has to be declared
system-wide.

The obvious place is wrong, and it fails silently. `/etc/nix/nix.custom.conf`
is a **Determinate Nix** feature, and although `determinate-nixd` is installed
here, the Nix that runs is upstream:

```
$ nix --version
nix (Nix) 2.31.4
$ strings $(readlink -f $(which nix)) | grep nix.custom.conf   # nothing
```

Written there, the settings are simply ignored — `nix config show` keeps
listing only `cache.nixos.org`, with no warning that a config file went unread.
(This was got wrong first: the string "user modification can go in
nix.custom.conf" is in the `determinate-nixd` binary, not in Nix.)

Upstream Nix reads `/etc/nix/nix.conf` and nothing else at the system level.
That file is installer-owned, and nix-darwin is kept away from it on purpose
(`nix.enable = false`, dotfiles-mac ADR 0014), so this stays a manual step
either way. What works is to keep the substituter and its public key in
`/etc/nix/nix.custom.conf` and append a single `!include` line to `nix.conf`:
that leaves almost nothing in the installer-owned file and puts later additions
somewhere stable. The commands are in the README, and the values are written in
one place in this repository rather than two on purpose.

The daemon performs substitution, so it has to be restarted
(`sudo launchctl kickstart -k system/org.nixos.nix-daemon`) before either file
takes effect. And because `nix.conf` is installer-owned, a Nix upgrade can drop
the `!include` and quietly stop the cache being used.

Declaring the one cache system-wide is the narrower grant. Adding the user to
`trusted-users` instead would let *any* flake's `nixConfig` inject a substituter,
which is a much larger promise for the same benefit.

Because Determinate owns that directory, this is a manual machine step, not a
declared one — it belongs with the rest of dotfiles-mac's manual setup.

**`inputs.nixpkgs.follows` would defeat the cache.**

If dotfiles-mac consumes this flake with `inputs.nixpkgs.follows = "nixpkgs"`,
`pkgs.myEmacs` is built from *dotfiles-mac's* nixpkgs, while CI builds against
*this* flake's lock. Different nixpkgs, different derivation hash, cache miss
every time. So this flake must be consumed **without** `follows`, using its own
pinned nixpkgs — which is also what decouples Emacs's bump cadence from the
system's, and is how `neovim-nightly-overlay` and `emacs-overlay` are consumed
already.

The cost of that is a second nixpkgs in the closure: more evaluation, more disk,
and potentially two versions of a shared library where one would do. Not
measured.

## Open questions

Deferred work lives in this repository's
[issues](https://github.com/hypatia-tile/emacs-flake/issues), not in a list
here: a list in a document cannot be closed, and it does not say when it has
gone stale ([#1](https://github.com/hypatia-tile/emacs-flake/issues/1)). The questions this section used to hold are
[#2](https://github.com/hypatia-tile/emacs-flake/issues/2) to [#5](https://github.com/hypatia-tile/emacs-flake/issues/5).

One was closed rather than moved: whether emacs-plus's empty AOT tree (Defect 2)
is a formula bug. Emacs no longer comes from emacs-plus on this machine
(dotfiles-mac ADR 0031), so settling it would be a report to that tap, not work
for this repository.
