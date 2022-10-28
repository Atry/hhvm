#!/usr/bin/env bash

nix store gc

timeout 3600 \
  nix build \
  --no-out-link \
  --print-build-logs \
  --override-input nixpkgs "git+file://$GITHUB_WORKSPACE/nixpkgs" \
  "git+file://$GITHUB_WORKSPACE/hhvm?submodules=1&shallow=1#$1"

TIMEOUT_EXIT_CODE=$?

if [[ "$TIMEOUT_EXIT_CODE" == 124 ]]
then
  exit 0
else
  exit "$TIMEOUT_EXIT_CODE"
fi