#!/usr/bin/env bash
set -euo pipefail

destination="$(xcodebuild -scheme AqualumeWatchApp -project Aqualume.xcodeproj -showdestinations 2>/dev/null | awk -F"'" '/platform:watchOS Simulator/ { print $2; exit }')"
if [[ -n "${destination}" ]]; then
  cmd=(xcodebuild -project Aqualume.xcodeproj -scheme AqualumeWatchApp -destination "${destination}" build)
else
  cmd=(xcodebuild -project Aqualume.xcodeproj -target AqualumeWatchApp -sdk watchsimulator26.1 build)
fi
printf '%q ' "${cmd[@]}"
echo
"${cmd[@]}"
