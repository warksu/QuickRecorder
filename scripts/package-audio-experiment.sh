#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${1:-}" == --release && $# == 1 ]]; then
    build_dir="$repo_dir/build/AudioRelease"
    app_path="$build_dir/DerivedData/Build/Products/Release/QuickRecorder-AudioExperiment.app"
    dmg_path="$build_dir/QuickRecorder-AudioCapture-1.6.9-arm64.dmg"
elif [[ $# == 0 ]]; then
    build_dir="$repo_dir/build/AudioExperiment"
    app_path="$build_dir/DerivedData/Build/Products/Debug/QuickRecorder-AudioExperiment.app"
    dmg_path="$build_dir/QuickRecorder-AudioExperiment-1.6.9-arm64.dmg"
else
    printf 'Usage: %s [--release]\n' "$0" >&2
    exit 2
fi

if [[ ! -d "$app_path" ]]; then
    printf 'Missing app: %s\n' "$app_path" >&2
    exit 1
fi
if [[ -e "$dmg_path" ]]; then
    printf 'DMG already exists; refusing to replace it: %s\n' "$dmg_path" >&2
    exit 1
fi
if [[ "$(lipo -archs "$app_path/Contents/MacOS/QuickRecorder-AudioExperiment")" != arm64 ]]; then
    printf '%s\n' 'Expected an Apple Silicon-only app.' >&2
    exit 1
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")" != com.lihaoyun6.QuickRecorder.AudioExperiment ]]; then
    printf '%s\n' 'Unexpected bundle identifier.' >&2
    exit 1
fi
codesign --verify --deep --strict "$app_path"

stage_dir="$(mktemp -d "$build_dir/dmg-stage.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
ditto "$app_path" "$stage_dir/QuickRecorder-AudioExperiment.app"
ln -s /Applications "$stage_dir/Applications"
cp "$repo_dir/scripts/INSTALL.txt" "$stage_dir/README.txt"

hdiutil create -quiet -fs HFS+ -format UDZO -imagekey zlib-level=9 \
    -volname 'QuickRecorder Audio Experiment' -srcfolder "$stage_dir" "$dmg_path"
hdiutil verify -quiet "$dmg_path"
printf 'Created: %s\n' "$dmg_path"
