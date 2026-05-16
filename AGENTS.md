# Repository Guidelines

## Project Structure & Module Organization

Aqualume is a SwiftUI hydration app with companion targets in one Xcode project. Main iOS app code lives in `Aqualume/`, organized by responsibility: `App/` for the entry point, `Domain/` for hydration models and calculations, `Persistence/` for storage, `Services/` for platform integrations, `Features/` for screens, and `SharedUI/` for reusable SwiftUI views. Tests live in `AqualumeTests/`. The watch app is in `AqualumeWatchApp/`, the WidgetKit extension is in `AqualumeWidget/`, and visual assets are under `Aqualume/Resources/Assets.xcassets/`. Project reference docs include `AQUALUME_SPEC.md`, `DESIGN_SYSTEM.md`, `VALIDATION.md`, and `ASSET_MANIFEST.md`.

## Build, Test, and Development Commands

Run commands from the repository root.

- `./Scripts/discover.sh`: lists Xcode schemes and available simulator destinations.
- `./Scripts/test.sh`: runs the `AqualumeTests` scheme with `xcodebuild test`.
- `./Scripts/build-ios.sh`: builds the main `Aqualume` iOS target.
- `./Scripts/build-widget.sh`: builds `AqualumeWidgetExtension`.
- `./Scripts/build-watch.sh`: builds `AqualumeWatchApp`, with a watch simulator SDK fallback.
- `./Scripts/validate-all.sh`: runs discovery, tests, and all target builds.
- `open Aqualume.xcodeproj`: opens the project for simulator or device work in Xcode.

## Coding Style & Naming Conventions

Use Swift conventions already present in the codebase: 4-space indentation, `PascalCase` for types, `camelCase` for methods and properties, and descriptive protocol names such as `ReminderScheduling` or `HydrationSyncing`. Keep app state in feature-level types, domain logic in `Aqualume/Domain/`, and platform APIs behind service protocols. Prefer small SwiftUI views in `SharedUI/` when they are reused across features. Avoid unrelated formatting churn in `project.pbxproj`.

## Testing Guidelines

Tests use XCTest and are grouped by behavior in `AqualumeTests/`, for example `HydrationLogicTests.swift` and `RepositoryTests.swift`. Name tests with `test...` plus the expected behavior, such as `testProgressClampsAtGoal`. Add unit tests for domain, persistence, settings, and service-facing behavior when changing those areas. Run `./Scripts/test.sh` before submitting and `./Scripts/validate-all.sh` for target-level confidence.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects, for example `Implement initial onboarding flow;` or `Add randomized messages for daily reminders;`. Keep subjects focused on one change and prefer clear verbs like `Add`, `Fix`, `Implement`, or `Remove`. Pull requests should include a brief summary, validation commands run, linked issue or spec section when relevant, and screenshots or simulator notes for UI changes. Call out any HealthKit, App Group, WatchConnectivity, notification, or provisioning behavior that needs device validation.

## Security & Configuration Tips

Do not commit personal signing settings, secrets, or provisioning artifacts. HealthKit, App Groups, widgets, and watch connectivity require valid entitlements and developer team configuration for device validation.
