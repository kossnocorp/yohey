#!/bin/bash
set -euo pipefail
[[ ${1:-} =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || { echo 'Expected X.Y.Z' >&2; exit 2; }
tag="app@$1"
ref="refs/tags/$tag"
repo=$(gh repo view "$(git remote get-url origin)" --json nameWithOwner --jq .nameWithOwner)
if result=$(gh api --silent "repos/$repo/releases/tags/$tag" 2>&1); then
  gh release delete "$tag" --repo "$repo" --yes
elif [[ $result != *'(HTTP 404)'* ]]; then
  echo "$result" >&2
  exit 1
fi
remote_tag=$(git ls-remote --tags origin "$ref")
if [[ -n $remote_tag ]]; then git push origin --delete "$ref"; fi
if git show-ref --verify --quiet "$ref"; then git tag --delete "$tag"; fi
