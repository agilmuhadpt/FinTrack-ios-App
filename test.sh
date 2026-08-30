#!/bin/bash
# Run the FinTrack UI test suite (gesture coverage) on the simulator.
set -o pipefail
BASE="${FINTRACK_DERIVED_DATA:-$(cd "$(dirname "$0")" && pwd)/.build}"
DD="$BASE/DerivedData"
cd "$(dirname "$0")" || exit 1
xcodebuild -project FinTrack.xcodeproj -scheme FinTrack -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath "$DD" "${@:-test}" 2>&1 \
  | grep -E "Test Case .* (passed|failed)|XCTAssert.* failed|error:|Testing failed|TEST (EXECUTE |BUILD )?(SUCCEEDED|FAILED)" \
  | sed 's/-\[FinTrackUITests\.//; s/\]//'
