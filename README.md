# Voda

Voda is simple, water drinking reminder, SwiftUI app for iPhone.

The core interaction is a large animated glass of water. The glass starts empty each day, fills as the user logs water, and celebrates goal completion with polished liquid motion.

## Targets

- `Voda`: iOS SwiftUI app.
- `VodaWidgetExtension`: WidgetKit widget with App Intent quick-add.
- `VodaTests`: unit tests for hydration logic, persistence, settings, and related behavior.

## Current Scope

The app currently includes:

- Animated filling Tumbler glass.
- One-tap hydration logging.
- Quick amounts: 100 ml, 250 ml, 330 ml, 500 ml.
- Undo latest log.
- Daily goal and unit settings.
- Local persistence.
- Local reminders.
- HealthKit dietary water write support.
- History charts for 30 days, 90 days, and 1 year.
- WidgetKit widget and App Intent quick-add.
- Generated visual assets integrated into the asset catalog.

## Requirements

- macOS with Xcode installed.
- iOS Simulator for CLI validation.
- Apple Developer team and provisioning setup for real-device HealthKit, App Groups, and widget/device testing.

## Build And Test

Use the CLI scripts in `Scripts/`:

```bash
./Scripts/discover.sh
./Scripts/test.sh
./Scripts/build-ios.sh
./Scripts/build-widget.sh
./Scripts/validate-all.sh
```

The scripts detect available projects, schemes, destinations, and SDK fallbacks where possible.

## Xcode

Open the project:

```bash
open Voda.xcodeproj
```

For device runs, select your development team on the app and widget targets. HealthKit and App Group behavior require valid signing and capabilities.

