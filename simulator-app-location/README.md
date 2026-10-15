# Simulator location example

Code for the article *Where did my simulator's location come from?* ([English](https://blog.masonships.app/en/posts/simulator-app-location/) · [中文](https://blog.masonships.app/zh/posts/simulator-app-location/)).

LocationProbe reproduces why a UI test that must start without a location can still find one: while the Simulator app is open with a location chosen in **Features ▸ Location**, it sends that location to a simulator as soon as the simulator boots, and `xcrun simctl location <device> clear` cannot remove a location the simulator has already received.

## What's here

- `LocationProbe/`: a one-screen app that shows the latest coordinate it receives and how many seconds after launch the first one arrived. It logs every location under the subsystem `com.example.LocationProbe`.
- `LocationProbeUITests/`: one UI test that launches the app, waits 10 seconds, and prints `PROBE coordinate: …`. It reports rather than judges.
- `scripts/`: one script per experiment. Each builds and installs LocationProbe, allows it to use location, and writes its results to the folder you name.

Tested with Xcode 26.5 on macOS 26.6.2, using an iPhone 16 Pro simulator running iOS 18.5. Run the scripts from this folder. They reboot the simulator you give them, so pick one you can spare:

```bash
xcrun simctl list devices
```

## Experiment 1: where does the location come from?

`scripts/observe-location.sh <UDID> <output-folder>` reboots the simulator, clears its location, launches LocationProbe, and takes a screenshot every 5 seconds for 60 seconds. Run it three times:

| Simulator app | Features ▸ Location | What LocationProbe shows |
|---|---|---|
| Closed | any | No location for 60 seconds |
| Open | None | No location for 60 seconds |
| Open | Custom Location | The custom coordinate, a fraction of a second after launch |

`device-log.txt` shows when the location arrived: in the third case it started about 6.5 seconds after boot, once a second, before the script cleared it at about 13 seconds.

## Experiment 2: why didn't clearing help?

Start with the Simulator app closed and a location chosen in Features ▸ Location. `scripts/leftover-location.sh <UDID> <output-folder>` relaunches LocationProbe after each step:

| Step | What LocationProbe receives |
|---|---|
| Rebooted and cleared | Nothing |
| `simctl location set` Melbourne | Melbourne, with updates |
| Cleared, not rebooted | Melbourne once, with no updates |
| Set Melbourne again, rebooted, not cleared | Nothing |
| Simulator app open, rebooted, not cleared | The Simulator app's location, with updates |
| Simulator app quit, rebooted, not cleared | Nothing |

Clearing stops new locations but leaves the last one the simulator received; a fresh boot removes it.

## Experiment 3: does the same happen in a UI test?

`scripts/run-probe-test.sh <UDID> <output-folder>` reboots and clears the simulator, then runs the UI test with `xcodebuild test-without-building`. With the Simulator app closed the test prints `No location yet`; with it open and a location chosen, it prints that location.

## Afterwards

Set Features ▸ Location back to what you use (None keeps it out of your tests), quit the Simulator app, and remove the app:

```bash
xcrun simctl uninstall <UDID> com.example.LocationProbe
```
