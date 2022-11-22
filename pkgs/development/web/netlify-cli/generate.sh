#!/usr/bin/env bash
set -eu -o pipefail
cd "$( dirname "${BASH_SOURCE[0]}" )"
rm -f ./node-env.nix
src="$(nix-build --expr 'let pkgs = import ../../../.. {}; lib = import ../../../../lib; meta = (lib.importJSON ./netlify-cli.json); in pkgs.fetchFromGitHub {owner = meta.owner; repo = meta.repo; rev = meta.rev; sha256 = meta.sha256;}')"
echo $src
node2nix \
  --input $src/package.json \
  --lock $src/npm-shrinkwrap.json \
  --output node-packages.nix \
  --composition composition.nix \
  --node-env node-env.nix \
  --nodejs-16 \
  ;
