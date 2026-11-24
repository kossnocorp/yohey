#!/bin/bash
set -euo pipefail
[[ ${1:-} =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || { echo 'Expected X.Y.Z' >&2; exit 2; }
[[ -z $(git status --porcelain) ]] || { echo 'Commit your changes first' >&2; exit 1; }
tag="app@$1"
git tag "$tag"
git push origin "refs/tags/$tag"
