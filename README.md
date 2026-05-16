# Aqualume

Aqualume is a premium SwiftUI hydration app for iPhone and Apple Watch.

Tagline: **Fill your day.**

The core interaction is a large animated glass of water. The glass starts empty each day, fills as the user logs water, and celebrates goal completion with polished liquid motion.

## Targets

- `Aqualume`: iOS SwiftUI app.
- `AqualumeWatchApp`: watchOS companion app.
- `AqualumeWidgetExtension`: WidgetKit widget with App Intent quick-add.
- `AqualumeTests`: unit tests for hydration logic, persistence, settings, and related behavior.

## Current Scope

The MVP includes:

- Animated filling Tumbler glass.
- One-tap hydration logging.
- Quick amounts: 100 ml, 250 ml, 330 ml, 500 ml.
- Undo latest log.
- Daily goal and unit settings.
- Local persistence.
- Local reminders.
- HealthKit dietary water write support.
- WatchConnectivity sync.
- 7-day history.
- WidgetKit widget and App Intent quick-add.
- Generated visual assets integrated into the asset catalog.

## Requirements

- macOS with Xcode installed.
- iOS Simulator for CLI validation.
- watchOS SDK/runtime for full watch simulator validation where available.
- Apple Developer team and provisioning setup for real-device HealthKit, App Groups, WatchConnectivity, and widget/device testing.

## Build And Test

Use the CLI scripts in `Scripts/`:

```bash
./Scripts/discover.sh
./Scripts/test.sh
./Scripts/build-ios.sh
./Scripts/build-watch.sh
./Scripts/build-widget.sh
./Scripts/validate-all.sh
```

The scripts detect available projects, schemes, destinations, and SDK fallbacks where possible.

## Xcode

Open the project:

```bash
open Aqualume.xcodeproj
```

For device runs, select your development team on the app, watch app, and widget targets. HealthKit and App Group behavior require valid signing and capabilities.

## Known Caveats

- HealthKit live write validation requires a signed build with the HealthKit entitlement.
- App Group runtime access requires a valid app group entitlement and provisioning profile.
- watchOS simulator validation depends on installed runtimes matching the local Xcode SDK.
- Manual validation is still recommended for notification delivery, paired WatchConnectivity behavior, widget gallery placement, App Intent execution, haptics, VoiceOver, and Reduce Motion.
