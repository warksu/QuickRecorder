#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
build_dir="$repo_dir/build/AudioRelease"
app_path="$build_dir/DerivedData/Build/Products/Release/QuickRecorder-AudioExperiment.app"
package_dir="$repo_dir/build/AudioExperiment"

if ! xcodebuild -checkFirstLaunchStatus; then
    printf '%s\n' 'Open Xcode and complete the license agreement and first-launch component installation.' >&2
    exit 1
fi

mkdir -p "$build_dir"
xcodebuild \
    -project "$repo_dir/QuickRecorder.xcodeproj" \
    -scheme QuickRecorder -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$build_dir/DerivedData" \
    -clonedSourcePackagesDirPath "$package_dir/SourcePackages" \
    -packageCachePath "$package_dir/PackageCache" \
    -onlyUsePackageVersionsFromResolvedFile \
    QUICKRECORDER_PRODUCT_SUFFIX=-AudioExperiment \
    QUICKRECORDER_BUNDLE_SUFFIX=.AudioExperiment \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$build_dir/build.log"

xcrun strip -S -x "$app_path/Contents/MacOS/QuickRecorder-AudioExperiment"
if rg -a -l '/Users/|/home/' "$app_path" >/dev/null; then
    printf '%s\n' 'Build contains absolute home paths; refusing to sign.' >&2
    exit 1
fi

codesign --force --deep --sign - \
    --entitlements "$repo_dir/QuickRecorder/QuickRecorder.entitlements" "$app_path"
codesign --verify --deep --strict "$app_path"
printf '\nBuilt: %s\n' "$app_path"
