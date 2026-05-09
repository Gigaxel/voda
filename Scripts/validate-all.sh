#!/usr/bin/env bash
set -euo pipefail

./Scripts/discover.sh
./Scripts/test.sh
./Scripts/build-ios.sh
./Scripts/build-widget.sh
if ./Scripts/build-watch.sh; then
  echo "watchOS build passed."
else
  echo "watchOS build blocked or failed."
  exit 1
fi
