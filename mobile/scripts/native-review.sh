#!/usr/bin/env bash
set -euo pipefail
runtime=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x["isAvailable"] and "iOS" in x["name"]]; print(r[-1]["identifier"])')
device=$(xcrun simctl create AstraReview com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro "$runtime")
trap 'xcrun simctl shutdown "$device" >/dev/null 2>&1 || true' EXIT
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b
xcrun simctl status_bar "$device" override --time '9:41' --batteryState charged --batteryLevel 100
xcrun simctl install "$device" build/Build/Products/Release-iphonesimulator/Astra.app
xcrun simctl launch "$device" com.lluviose.astra.modern
sleep 12
xcrun simctl io "$device" screenshot verification/native-collection.png
for page in journal hall person/lin record; do
  xcrun simctl openurl "$device" "astra-modern:///$page"
  sleep 3
  filename=${page//\//-}
  xcrun simctl io "$device" screenshot "verification/native-$filename.png"
done
