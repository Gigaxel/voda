#!/usr/bin/env bash
set -euo pipefail

./Scripts/discover.sh
./Scripts/test.sh
./Scripts/build-ios.sh
./Scripts/build-widget.sh
