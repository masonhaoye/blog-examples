#!/bin/bash
# Experiment 2: why didn't clearing help?
#
# Checks which steps remove a location the simulator has already received: first one set with
# `simctl location set`, then one sent by the Simulator app. For each step it relaunches LocationProbe,
# waits 15 seconds, and records what the app received.
#
# Start with the Simulator app closed and a location chosen in its Features > Location menu (for example
# Custom Location). The script opens and quits the Simulator app itself.
#
# Usage: scripts/leftover-location.sh <simulator-UDID> <output-folder>
# The simulator is rebooted; use one you don't need for anything else. Set DERIVED_DATA to choose
# where LocationProbe is built.
set -euo pipefail
udid=$1
out=$2
here="$(cd "$(dirname "$0")" && pwd)"
project="$here/../LocationProbe.xcodeproj"
derived_data="${DERIVED_DATA:-${TMPDIR:-/tmp}/LocationProbeDerivedData}"
melbourne=-37.813600,144.963100

if pgrep -x Simulator > /dev/null; then
    echo "Quit the Simulator app first; the first steps need it closed." >&2
    exit 2
fi
# 5101 is Features > Location > None (observed with Xcode 26.5).
if [[ $(defaults read com.apple.iphonesimulator LocationMode 2>/dev/null) == 5101 ]]; then
    echo "Choose a location in the Simulator app's Features > Location menu (not None), then quit it." >&2
    exit 2
fi
mkdir -p "$out"
: > "$out/summary.txt"

# Build and install LocationProbe, and allow it to use location without a prompt.
xcrun simctl bootstatus "$udid" -b > /dev/null
xcodebuild build-for-testing -project "$project" -scheme LocationProbe -destination "id=$udid" \
    -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=NO > "$out/build.log" 2>&1
xcrun simctl install "$udid" "$derived_data/Build/Products/Debug-iphonesimulator/LocationProbe.app"
xcrun simctl privacy "$udid" grant location com.example.LocationProbe

reboot() {
    xcrun simctl shutdown "$udid" 2> /dev/null || true
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" > /dev/null
}

observe() {
    local name=$1 description=$2 started
    xcrun simctl terminate "$udid" com.example.LocationProbe 2> /dev/null || true
    sleep 1  # log show starts on a whole second; keep the previous launch out of this window
    started=$(date '+%Y-%m-%d %H:%M:%S')
    # A newly created simulator can refuse to launch apps for a while after it reports that it has booted.
    local attempt
    for attempt in $(seq 30); do
        xcrun simctl launch "$udid" com.example.LocationProbe > /dev/null 2>&1 && break
        if (( attempt == 30 )); then
            echo "LocationProbe did not launch within 30 seconds." >&2
            exit 1
        fi
        sleep 1
    done
    sleep 15
    xcrun simctl io "$udid" screenshot "$out/$name.png" > /dev/null 2>&1
    xcrun simctl spawn "$udid" log show --start "$started" --info --style compact \
        --predicate 'subsystem == "com.example.LocationProbe"' 2> /dev/null \
        | grep -F "[com.example.LocationProbe:location] Location" | sed 's/^.*\] //' > "$out/$name.txt" || true
    printf '%-46s %s (%s in 15 s)\n' "$description:" "$(head -1 "$out/$name.txt" | grep . || echo 'no location')" \
        "$(wc -l < "$out/$name.txt" | tr -d ' ')" | tee -a "$out/summary.txt"
}

# A location set with simctl, Simulator app closed.
reboot
xcrun simctl location "$udid" clear
observe 1-clean "Rebooted and cleared"

xcrun simctl location "$udid" set "$melbourne"
observe 2-set "Set Melbourne with simctl"

xcrun simctl location "$udid" clear
observe 3-clear-only "Cleared, not rebooted"

xcrun simctl location "$udid" set "$melbourne"
reboot
observe 4-reboot-only "Set Melbourne again, rebooted, not cleared"

# A location sent by the Simulator app.
open -a Simulator
sleep 5
reboot
sleep 10
observe 5-app-sent "Simulator app open, rebooted, not cleared"

osascript -e 'quit app "Simulator"' > /dev/null 2>&1 || true
sleep 3
pkill -x Simulator || true  # the quit request is sometimes ignored
sleep 2
reboot
observe 6-app-quit-reboot-only "Simulator app quit, rebooted, not cleared"
