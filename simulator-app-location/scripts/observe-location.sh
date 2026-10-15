#!/bin/bash
# Experiment 1: where does the location come from?
#
# Prepares a simulator the way a UI test script would (reboot, then `simctl location clear`), launches
# LocationProbe, and takes a screenshot every 5 seconds for 60 seconds. Run it once for each state of the
# Simulator app: closed; open with Features > Location > None; open with a location chosen there
# (for example Custom Location).
#
# Usage: scripts/observe-location.sh <simulator-UDID> <output-folder>
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
started=$(date '+%Y-%m-%d %H:%M:%S')
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" > /dev/null
xcrun simctl location "$udid" clear
echo "$(date '+%H:%M:%S') booted and cleared" | tee -a "$out/conditions.txt"

# A newly created simulator can refuse to launch apps for a while after it reports that it has booted.
for attempt in $(seq 30); do
    xcrun simctl launch "$udid" com.example.LocationProbe > /dev/null 2>&1 && break
    if (( attempt == 30 )); then
        echo "LocationProbe did not launch within 30 seconds." >&2
        exit 1
    fi
    sleep 1
done
launched=$(date +%s)
echo "$(date '+%H:%M:%S') launched (attempt $attempt)" | tee -a "$out/conditions.txt"
for second in $(seq 0 5 60); do
    while (( $(date +%s) - launched < second )); do sleep 0.2; done
    xcrun simctl io "$udid" screenshot "$out/t$(printf %02d "$second").png" > /dev/null 2>&1
done

# Everything LocationProbe and the simulator's location daemon logged since the reboot.
xcrun simctl spawn "$udid" log show --start "$started" --info --debug --style compact \
    --predicate 'subsystem == "com.example.LocationProbe" OR process == "locationd"' > "$out/device-log.txt" 2>&1 || true
grep -F "[com.example.LocationProbe:location]" "$out/device-log.txt" | sed "s/^\([0-9:. -]*\).*\] /\1 /" | tee "$out/probe-log.txt"
