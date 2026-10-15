#!/bin/bash
# Experiment 3: does the same happen in an automated UI test?
#
# Prepares the simulator the way a UI test script would (install, allow location, reboot, clear), then
# runs LocationProbe's UI test with xcodebuild and prints what the app showed 10 seconds after launch.
# Run it with the Simulator app closed, and again with it open and a location chosen in its
# Features > Location menu.
#
# Usage: scripts/run-probe-test.sh <simulator-UDID> <output-folder>
# The simulator is rebooted; use one you don't need for anything else. Set DERIVED_DATA to choose
# where LocationProbe is built.
set -euo pipefail
udid=$1
out=$2
here="$(cd "$(dirname "$0")" && pwd)"
project="$here/../LocationProbe.xcodeproj"
derived_data="${DERIVED_DATA:-${TMPDIR:-/tmp}/LocationProbeDerivedData}"
mkdir -p "$out"

{
    echo "Simulator app running: $(pgrep -x Simulator > /dev/null && echo yes || echo no)"
    echo "Features > Location (LocationMode): $(defaults read com.apple.iphonesimulator LocationMode 2>/dev/null || echo unset)"
} | tee "$out/conditions.txt"

# Build and install LocationProbe, and allow it to use location without a prompt.
xcrun simctl bootstatus "$udid" -b > /dev/null
xcodebuild build-for-testing -project "$project" -scheme LocationProbe -destination "id=$udid" \
    -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO > "$out/build.log" 2>&1
xcrun simctl install "$udid" "$derived_data/Build/Products/Debug-iphonesimulator/LocationProbe.app"
xcrun simctl privacy "$udid" grant location com.example.LocationProbe

# What a UI test script does before a test that must start without a location.
xcrun simctl shutdown "$udid"
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" > /dev/null
xcrun simctl location "$udid" clear
started=$(date '+%Y-%m-%d %H:%M:%S')

xcodebuild test-without-building -project "$project" -scheme LocationProbe -destination "id=$udid" \
    -derivedDataPath "$derived_data" -resultBundlePath "$out/result.xcresult" > "$out/xcodebuild.log" 2>&1 || true

grep -E "^PROBE|\*\* TEST" "$out/xcodebuild.log" | tee "$out/probe-result.txt"
xcrun simctl spawn "$udid" log show --start "$started" --info --style compact \
    --predicate 'subsystem == "com.example.LocationProbe"' 2> /dev/null \
    | grep -F "[com.example.LocationProbe:location]" | sed 's/^.*\] //' | tee "$out/probe-log.txt"
