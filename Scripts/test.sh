#!/usr/bin/env bash
set -euo pipefail

destination="$(xcodebuild -scheme VodaTests -project Voda.xcodeproj -showdestinations 2>/dev/null | awk -F"'" '/platform:iOS Simulator/ { print $2; exit }')"
if [[ -z "${destination}" ]]; then
  destination="platform=iOS Simulator,name=iPhone 17"
fi

cmd=(xcodebuild -project Voda.xcodeproj -scheme VodaTests -destination "${destination}" test)
printf '%q ' "${cmd[@]}"
echo
"${cmd[@]}"
