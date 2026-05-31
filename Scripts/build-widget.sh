#!/usr/bin/env bash
set -euo pipefail

destination="$(xcodebuild -scheme AqualumeWidgetExtension -project Aqualume.xcodeproj -showdestinations 2>/dev/null | awk -F"'" '/platform:iOS Simulator/ { print $2; exit }')"
if [[ -n "${destination}" ]]; then
  cmd=(xcodebuild -project Aqualume.xcodeproj -scheme AqualumeWidgetExtension -destination "${destination}" build)
else
  cmd=(xcodebuild -project Aqualume.xcodeproj -scheme AqualumeWidgetExtension -destination "generic/platform=iOS" build CODE_SIGNING_ALLOWED=NO -derivedDataPath build)
fi
printf '%q ' "${cmd[@]}"
echo
if "${cmd[@]}"; then
  exit 0
fi

echo "Simulator widget build failed; retrying widget target build without code signing."
fallback=(xcodebuild -project Aqualume.xcodeproj -scheme AqualumeWidgetExtension -destination "generic/platform=iOS" build CODE_SIGNING_ALLOWED=NO -derivedDataPath build)
printf '%q ' "${fallback[@]}"
echo
"${fallback[@]}"
