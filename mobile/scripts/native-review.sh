#!/usr/bin/env bash
set -euo pipefail
runtime=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x["isAvailable"] and "iOS" in x["name"]]; print(r[-1]["identifier"])')
device=$(xcrun simctl create AstraReview com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro "$runtime")
trap 'xcrun simctl shutdown "$device" >/dev/null 2>&1 || true' EXIT
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b
xcrun simctl status_bar "$device" override --time '9:41' --batteryState charged --batteryLevel 100
mkdir -p verification
status=0
xcodebuild test -workspace ios/Astra.xcworkspace -scheme Astra-UIReview \
  -configuration Release -destination "platform=iOS Simulator,id=$device" \
  -derivedDataPath build -resultBundlePath verification/UIReview.xcresult \
  -parallel-testing-enabled NO ARCHS="$(uname -m)" ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO \
  > verification/native-ui-test.log 2>&1 || status=$?
if [ -d verification/UIReview.xcresult ]; then
  xcrun xcresulttool export attachments --path verification/UIReview.xcresult --output-path verification/screenshots
fi
exit "$status"
