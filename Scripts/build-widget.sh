#!/usr/bin/env bash
set -euo pipefail

destination="$(xcodebuild -scheme VodaWidgetExtension -project Voda.xcodeproj -showdestinations 2>/dev/null | awk -F"'" '/platform:iOS Simulator/ { print $2; exit }')"
if [[ -n "${destination}" ]]; then
  cmd=(xcodebuild -project Voda.xcodeproj -scheme VodaWidgetExtension -destination "${destination}" build)
else
  cmd=(xcodebuild -project Voda.xcodeproj -scheme VodaWidgetExtension build CODE_SIGNING_ALLOWED=NO -derivedDataPath build)
fi
printf '%q ' "${cmd[@]}"
echo
if "${cmd[@]}"; then
  exit 0
fi

echo "Simulator widget build failed; retrying widget target build without code signing."
fallback=(xcodebuild -project Voda.xcodeproj -scheme VodaWidgetExtension build CODE_SIGNING_ALLOWED=NO -derivedDataPath build)
printf '%q ' "${fallback[@]}"
echo
"${fallback[@]}"
