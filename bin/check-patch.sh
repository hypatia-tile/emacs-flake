#!/usr/bin/env bash
# Checks that frame-transparency applies to the Emacs source this flake's lock
# pins, with no fuzz allowed.
#
# The build itself would accept fuzz: stdenv's patchPhase runs plain
# `patch -p1`, which tolerates two lines of drift. A patch to six C files of
# the NS port that only applies approximately is a patch that may compile and
# still be wrong, so this fails first and says why, rather than leaving the
# question to a build log twenty minutes later. See issue #2.
#
# nixpkgs' own patches are applied first, in the order stdenv applies them,
# so the check sees the tree the patch really lands on.
set -euo pipefail

cd "$(dirname "$0")/.."
patch_file=patches/frame-transparency-emacs-31.patch
nix_flags=(--no-update-lock-file)

version=$(nix eval "${nix_flags[@]}" --raw .#emacs-ns.version)
src=$(nix build "${nix_flags[@]}" --no-link --print-out-paths .#emacs-ns.src)
gnupatch=$(nix build "${nix_flags[@]}" --no-link --print-out-paths --inputs-from . nixpkgs#gnupatch)/bin/patch
echo "emacs $version from $src"

work=$(mktemp -d)
trap 'chmod -R u+w "$work"; rm -rf "$work"' EXIT
cp -R "$src" "$work/src"
chmod -R u+w "$work/src"

for p in $(nix eval "${nix_flags[@]}" --json .#emacs-ns.patches | jq -r '.[]'); do
  [ -e "$p" ] || nix-store --realise "$p" >/dev/null
  echo "nixpkgs: $(basename "$p")"
  "$gnupatch" -p1 --batch --quiet --directory="$work/src" <"$p"
done

echo "ours:    $(basename "$patch_file") (-F 0)"
if ! out=$("$gnupatch" -p1 --batch --forward -F 0 --directory="$work/src" <"$patch_file" 2>&1); then
  echo "$out"
  msg="$patch_file does not apply to Emacs $version without fuzz. Look for a newer one in d12frosted/homebrew-emacs-plus, community/patches/frame-transparency/."
  if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::error file=$patch_file::$msg"; else echo "error: $msg" >&2; fi
  exit 1
fi
echo "$out"
echo "ok: applies cleanly to Emacs $version"
