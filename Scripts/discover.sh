#!/usr/bin/env bash
set -euo pipefail

project="$(find . -maxdepth 2 \( -name "*.xcworkspace" -o -name "*.xcodeproj" \) -print | head -1)"
if [[ -z "${project}" ]]; then
  echo "No Xcode project or workspace found."
  exit 1
fi

echo "Project: ${project}"
xcodebuild -list -project Aqualume.xcodeproj
echo
xcrun simctl list devices available | sed -n '1,80p'
