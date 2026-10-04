#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
build_dir="$repo_dir/build/AudioExperiment"
app_path="$build_dir/DerivedData/Build/Products/Debug/QuickRecorder-AudioExperiment.app"

if ! xcodebuild -checkFirstLaunchStatus; then
    printf '%s\n' 'Open Xcode and complete the license agreement and first-launch component installation.' >&2
    exit 1
fi

mkdir -p "$build_dir"
xcodebuild \
    -project "$repo_dir/QuickRecorder.xcodeproj" \
    -scheme QuickRecorder -configuration Debug -destination 'platform=macOS' \
    -derivedDataPath "$build_dir/DerivedData" \
    -clonedSourcePackagesDirPath "$build_dir/SourcePackages" \
    -packageCachePath "$build_dir/PackageCache" \
    -disablePackageRepositoryCache -onlyUsePackageVersionsFromResolvedFile \
    QUICKRECORDER_PRODUCT_SUFFIX=-AudioExperiment \
    QUICKRECORDER_BUNDLE_SUFFIX=.AudioExperiment \
    CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$build_dir/build.log"

codesign --force --deep --sign - \
    --entitlements "$repo_dir/QuickRecorder/QuickRecorder.entitlements" "$app_path"
codesign --verify --deep --strict "$app_path"
printf '\nBuilt: %s\n' "$app_path"
