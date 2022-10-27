#!/usr/bin/env bash

nix store gc

timeout 1800 \
  nix build \
  --print-build-logs \
  --override-input "$GITHUB_WORKSPACE/nixpkgs" github:NixOS/nixpkgs \
  "git+file://$GITHUB_WORKSPACE/hhvm?submodules=1&shallow=1#${{matrix.package}}"

TIMEOUT_EXIT_CODE=$?

if [[ "$TIMEOUT_EXIT_CODE" == 124 ]]
then
  exit 0
else
  exit "$TIMEOUT_EXIT_CODE"
fi