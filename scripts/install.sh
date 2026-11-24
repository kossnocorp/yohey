#!/bin/bash
# The release workflow stamps these constants before publishing this installer.
set -euo pipefail
repo='@REPOSITORY@'
team='@TEAM_ID@'
tag='@TAG@'
[[ $(uname -s) == Darwin && $team =~ ^[A-Z0-9]{10}$ ]] || { echo 'Use the published macOS installer.' >&2; exit 1; }
data=${XDG_DATA_HOME:-$HOME/.local/share}/yohey
bin=${XDG_BIN_HOME:-$HOME/.local/bin}
[[ $data == /* && $bin == /* ]] || { echo 'Install paths must be absolute' >&2; exit 1; }
mkdir -p "$data" "$bin"
tmp=$(mktemp -d "$data/.install.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
base="https://github.com/$repo/releases/download/$tag"
case $# in
  0) for file in Yohey.zip SHA256SUMS; do curl -fsSL "$base/$file" -o "$file"; done ;;
  2) [[ $1 == --from-dir && $2 == /* ]] || exit 2
     cp "$2/Yohey.zip" "$2/SHA256SUMS" . ;;
  *) echo 'Usage: install.sh [--from-dir /absolute/release-assets]' >&2; exit 2 ;;
esac
grep -E '^[[:xdigit:]]{64}  Yohey\.zip$' SHA256SUMS > archive.sha256
shasum -a 256 -c archive.sha256
ditto -x -k Yohey.zip unpack
app=unpack/Yohey.app
codesign --verify --strict -R="anchor apple generic and identifier \"com.kossnocorp.yohey\" and certificate leaf[subject.OU] = \"$team\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists" "$app"
spctl --assess --type execute "$app"
# Preserve the previous installation if the rename fails.
if [[ -e $data/Yohey.app ]]; then mv "$data/Yohey.app" previous.app; fi
if ! mv "$app" "$data/Yohey.app"; then [[ ! -d previous.app ]] || mv previous.app "$data/Yohey.app"; exit 1; fi
printf '#!/bin/bash\nexec /usr/bin/open %q\n' "$data/Yohey.app" > launcher
install -m 755 launcher "$bin/yohey"
printf 'Installed %s. Launch with: %q\n' "$data/Yohey.app" "$bin/yohey"
