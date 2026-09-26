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

Transparency cannot decide anything: it does not work on the Homebrew native
build either, so it is unchanged by the move. `--with-modules` is present in
both candidates, so a module-based route stays open.

`CFBundleIdentifier` is `org.gnu.Emacs` for both the Nix and Homebrew bundles,
which is what macSKK keys its 直接入力 list on (dotfiles-mac ADR 0029), so that
hand-made configuration carries over.

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

One convergence worth noting: Emacs 31 is the version whose Flymake puts every
backend behind `trusted-content`, which cost a day on the NixOS machine. The fix
is already committed in the Emacs config repo (`hypatia-tile/emacs-mac`,
4c4e1c3, closing its issue #3), so choosing 31.1 does not reopen it.

## What a dedicated repository buys, and what it does not

**Buys:** control over the source revision and the build flags, in one place,
with the reasoning recorded next to it. If the answer turns out to need a patch
or a revision nixpkgs does not carry, this is where that lives.

**Does not buy:** a cheaper build. Overriding anything changes the derivation
hash and drops the result out of `cache.nixos.org`, so the local compile happens
on every bump, not only when Emacs changes. A dedicated repository makes that
cost *deliberate*; it does not remove it. Removing it would take a binary cache
of one's own.

Which means: if `emacs` 31.1 proves acceptable as it comes, the honest
conclusion is that no override is needed and this repository is a record rather
than a build. That is an acceptable outcome, and the reason it was created
before the trial rather than after.

## Open questions

- **`emacs` 31.1 has not been trialled.** It is a download away and is the next
  step.
- **imagemagick.** Both Nix candidates pass `--without-imagemagick`, which
  emacs-plus enables. Whether anything is actually lost was not tested; the
  macport uses macOS-native image APIs, which is a reason to expect not.
- **Transparency** is unsolved in every build tried, Homebrew and Nix alike.
  `--with-modules` is present everywhere, so the module route
  (window-blur / emacs-liquid-glass) is untouched but also unexplored.
- **Permissions across rebuilds.** Both bundles are ad-hoc signed with no team
  identifier, and their codesign identifiers differ — `Emacs` for the Nix build,
  `org.gnu.Emacs` for Homebrew's. TCC grants for an ad-hoc bundle key on path
  and cdhash, and a store path changes on every rebuild, so Accessibility /
  Input Monitoring / Full Disk Access grants are expected to reset each time a
  Nix Emacs is rebuilt. This was reasoned from how the bundles are signed, not
  observed; it may well be what "many things were broken" meant in July.
- **Whether emacs-plus's empty AOT tree is a formula bug** worth reporting
  upstream. Settling it needs the rebuild described above.
