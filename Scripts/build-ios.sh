#!/usr/bin/env bash
set -euo pipefail

destination="$(xcodebuild -scheme Aqualume -project Aqualume.xcodeproj -showdestinations 2>/dev/null | awk -F"'" '/platform:iOS Simulator/ { print $2; exit }')"
if [[ -z "${destination}" ]]; then
  destination="platform=iOS Simulator,name=iPhone 17"
fi

cmd=(xcodebuild -project Aqualume.xcodeproj -scheme Aqualume -destination "${destination}" build)
printf '%q ' "${cmd[@]}"
echo
if "${cmd[@]}"; then
  exit 0
fi

echo "Simulator scheme build failed; retrying installable iOS device build without code signing."
fallback=(xcodebuild -project Aqualume.xcodeproj -target Aqualume build CODE_SIGNING_ALLOWED=NO)
printf '%q ' "${fallback[@]}"
echo
"${fallback[@]}"
