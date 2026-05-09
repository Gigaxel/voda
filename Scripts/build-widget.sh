#!/usr/bin/env bash
set -euo pipefail

destination="$(xcodebuild -scheme AqualumeWidgetExtension -project Aqualume.xcodeproj -showdestinations 2>/dev/null | awk -F"'" '/platform:iOS Simulator/ { print $2; exit }')"
if [[ -z "${destination}" ]]; then
  destination="platform=iOS Simulator,name=iPhone 17"
fi

cmd=(xcodebuild -project Aqualume.xcodeproj -scheme AqualumeWidgetExtension -destination "${destination}" build)
printf '%q ' "${cmd[@]}"
echo
"${cmd[@]}"
