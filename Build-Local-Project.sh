#!/usr/bin/env bash
# Assemble the complete, source-verified Spotify Corner Player project from the
# owner's private canonical archive. Safe: does not publish, push, or overwrite.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DEST="${SPOTIFY_PROJECT_DIR:-$HOME/projects/PersonalProjects/Spotify-Corner-Player}"
ARCHIVE='System/Marah Devices & Services/Spotify Corner Player'
REPO='Ali7488/pharm'

for cmd in gh git python3 base64; do
    command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd" >&2; exit 1; }
done

gh auth status >/dev/null || { echo 'GitHub CLI needs authentication. Run: gh auth login' >&2; exit 1; }

if [[ -e "$DEST" || -L "$DEST" ]]; then
    echo "Refusing to overwrite an existing project directory: $DEST" >&2
    echo 'Set SPOTIFY_PROJECT_DIR to a new empty/nonexistent path if appropriate.' >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/project" "$TMP/project/docs" "$TMP/project/dist"

copy_template() {
    local filename="$1"
    [[ -f "$ROOT/$filename" ]] || { echo "Missing bootstrap file: $filename" >&2; exit 1; }
    cp -- "$ROOT/$filename" "$TMP/project/$filename"
}
for f in Install.bat Uninstall.bat Setup.ps1 README.md .gitignore; do
    copy_template "$f"
done

# GitHub's contents API provides unmodified UTF-8 source in base64. Verify Git
# blob SHA-1 rather than raw ZIP byte SHA-256, since Git normalizes line endings.
fetch_verified() {
    local filename="$1" expected="$2" destination="$3"
    local encoded name
    name="$(python3 - "$ARCHIVE" "$filename" <<'PY'
import sys, urllib.parse
print('/'.join(urllib.parse.quote(x, safe='') for x in (*sys.argv[1].split('/'), sys.argv[2])))
PY
)"
    echo "Fetching and verifying: $filename"
    gh api "repos/$REPO/contents/$name" --jq .content | base64 --decode > "$destination"
    local actual
    actual="$(git hash-object "$destination")"
    if [[ "$actual" != "$expected" ]]; then
        echo "Source mismatch for $filename: expected $expected; got $actual" >&2
        exit 1
    fi
}

fetch_verified 'Spotify-Corner-Player-v1.2.4.ps1' \
    'f1935794f1220fefe08c5e2c6c8efa8054f75ecb' \
    "$TMP/project/Spotify-Corner-Player-v1.2.4.ps1"
fetch_verified 'Install-SpotifyPlayerLogs.ps1' \
    '318cb3b64ba92252528ea0b5dff8c854389c39d9' \
    "$TMP/project/Install-SpotifyPlayerLogs.ps1"
fetch_verified 'Spotify-Corner-Player-v1.2.3-rollback.ps1' \
    'afdf20fcb5b23014b988057b61ed2e0d3aa2a853' \
    "$TMP/project/Spotify-Corner-Player-v1.2.3-rollback.ps1"
fetch_verified 'Spotify-Corner-Player-v1.2.0-rollback.ps1' \
    'de6edb4b098e3beec2480eb3fb1cd2de4d042aeb' \
    "$TMP/project/Spotify-Corner-Player-v1.2.0-rollback.ps1"
fetch_verified 'README-v1.2.4.md' \
    '473039b64af1f435bd6c24717567f3188261ac37' \
    "$TMP/project/docs/Archived-Release-README.md"

# Store the reusable bootstrap script in the new repository itself, too.
cp -- "$ROOT/Build-Local-Project.sh" "$TMP/project/Build-Local-Project.sh"
chmod +x "$TMP/project/Build-Local-Project.sh"

python3 - "$TMP/project" <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import sys
root = Path(sys.argv[1])
names = [
    'Install.bat', 'Uninstall.bat', 'Setup.ps1',
    'Spotify-Corner-Player-v1.2.4.ps1',
    'Install-SpotifyPlayerLogs.ps1',
    'Spotify-Corner-Player-v1.2.3-rollback.ps1',
    'Spotify-Corner-Player-v1.2.0-rollback.ps1',
    'README.md',
]
output = root / 'dist' / 'Spotify-Corner-Player-v1.2.4-Windows.zip'
with ZipFile(output, 'w', ZIP_DEFLATED, compresslevel=9) as archive:
    for name in names:
        archive.write(root / name, arcname=name)
with ZipFile(output) as archive:
    if archive.testzip() is not None:
        raise RuntimeError('Final Windows ZIP failed its CRC test')
print('Generated:', output)
PY

mkdir -p -- "$(dirname -- "$DEST")"
# Atomic on the same filesystem? mktemp may reside on /tmp instead; do not
# overwrite even when the requested destination has appeared meanwhile.
if [[ -e "$DEST" || -L "$DEST" ]]; then
    echo "Destination was created during assembly; refusing overwrite: $DEST" >&2
    exit 1
fi
mkdir -- "$DEST"
cp -a "$TMP/project/." "$DEST/"
if ! git -C "$DEST" init -b main >/dev/null; then
    echo "Git initialization failed. Files remain at: $DEST" >&2
    exit 1
fi
printf '\nComplete project: %s\n' "$DEST"
printf 'Windows ZIP:      %s\n' "$DEST/dist/Spotify-Corner-Player-v1.2.4-Windows.zip"
printf '\nReview and push only when ready:\n'
printf '  cd %q\n  git add .\n  git commit -m "Import Spotify Corner Player v1.2.4 with one-click Windows setup"\n  gh repo create Spotify-Corner-Player --private --source . --remote origin --push\n' "$DEST"
