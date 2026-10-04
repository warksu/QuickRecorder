#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/quickrecorder-audio-tests.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT

swiftc -swift-version 5 -D AUDIO_TIMELINE_STANDALONE -module-cache-path "$build_dir/ModuleCache" \
    "$repo_dir/QuickRecorder/Supports/RecordingTimeline.swift" \
    "$repo_dir/Tests/RecordingTimelineTests.swift" \
    -o "$build_dir/RecordingTimelineTests"
"$build_dir/RecordingTimelineTests"
