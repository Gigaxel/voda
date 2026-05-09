# Aqualume Validation

## Purpose

Validation should be CLI-first. Use Xcode only for visual inspection, capability setup, and platform flows that cannot be fully validated from the command line.

Create scripts during implementation, not now:

- `Scripts/discover.sh`
- `Scripts/build-ios.sh`
- `Scripts/build-watch.sh`
- `Scripts/build-widget.sh`
- `Scripts/test.sh`
- `Scripts/validate-all.sh`

Scripts should detect available schemes and destinations instead of hardcoding a single local simulator whenever possible.

## Project Discovery

List schemes:

```bash
xcodebuild -list
```

List available destinations for a known scheme:

```bash
xcodebuild -showdestinations -scheme Aqualume
```

List simulators:

```bash
xcrun simctl list devices available
```

List runtimes:

```bash
xcrun simctl list runtimes
```

Find workspace or project:

```bash
find . -maxdepth 2 \( -name "*.xcworkspace" -o -name "*.xcodeproj" \) -print
```

Acceptance:

- A project or workspace exists after Milestone 0.
- Expected schemes are visible.
- At least one iOS simulator destination is available.
- watchOS destinations are available where the local Xcode install supports them.

## Build iOS

Preferred command once the scheme exists:

```bash
xcodebuild \
  -scheme Aqualume \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

Fallback destination discovery:

```bash
xcodebuild -scheme Aqualume -showdestinations
```

Script expectation:

```bash
./Scripts/build-ios.sh
```

Script behavior:

- Detect `.xcworkspace` first, otherwise `.xcodeproj`.
- Detect the Aqualume iOS scheme.
- Select an available iOS Simulator.
- Print the exact xcodebuild command before running it.
- Exit nonzero on failure.

Acceptance:

- Main app target compiles.
- No Swift compiler errors.
- No missing asset catalog references.
- No missing entitlements caused by local configuration mistakes.

## Build watchOS

Preferred command once the watch scheme exists:

```bash
xcodebuild \
  -scheme AqualumeWatchApp \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  build
```

Fallback destination discovery:

```bash
xcodebuild -scheme AqualumeWatchApp -showdestinations
```

Script expectation:

```bash
./Scripts/build-watch.sh
```

Script behavior:

- Detect available watchOS schemes.
- Detect available watchOS simulator destinations.
- Build the watch app target where possible.
- If no watchOS runtime is installed, exit with a clear blocked message and record it in PROGRESS.md.

Acceptance:

- Watch app target compiles where SDK/runtime is available.
- Shared code compiles for watchOS without unavailable iOS-only APIs leaking into watch targets.

## Build Widget

Preferred command once the widget target exists:

```bash
xcodebuild \
  -scheme AqualumeWidgetExtension \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

If the widget does not have a standalone scheme, build through the main app scheme:

```bash
xcodebuild \
  -scheme Aqualume \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

Script expectation:

```bash
./Scripts/build-widget.sh
```

Acceptance:

- Widget extension compiles.
- App Intent compiles.
- Shared persistence access compiles.

## Unit Tests

Preferred command:

```bash
xcodebuild \
  -scheme Aqualume \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

Script expectation:

```bash
./Scripts/test.sh
```

Required test coverage:

- Hydration logging adds canonical milliliter amounts.
- Quick amounts include 100 ml, 250 ml, 330 ml, 500 ml.
- Daily total sums current-day logs.
- New day starts visually empty without deleting history.
- Progress calculation handles 0, partial, goal, and over-goal totals.
- Undo removes the latest current-day log.
- Unit display supports ml/L and oz.
- Settings validation prevents invalid goals and default amounts.
- Repository tests persist logs and settings.
- Sync tests avoid duplicate log IDs where feasible.

Acceptance:

- Unit tests pass from CLI.
- Tests do not require HealthKit, notifications, WatchConnectivity, or simulator pairing.
- Apple framework integrations use mocks where practical.

## Complete Validation

Script expectation:

```bash
./Scripts/validate-all.sh
```

Required sequence:

1. Discover project, schemes, and destinations.
2. Run unit tests.
3. Build iOS app.
4. Build watchOS app if available.
5. Build widget target if available or through app scheme.
6. Print a concise summary.

Acceptance:

- Complete validation exits zero when all available checks pass.
- Unavailable optional platform checks are reported as blocked, not silently skipped.
- PROGRESS.md records the result after each milestone.

## Manual Validation

Some Apple platform behaviors may need simulator or device validation:

- Notification permission prompt.
- Delivery of local notifications.
- HealthKit authorization flow.
- Health app dietary water sample visibility.
- WatchConnectivity paired-device behavior.
- Widget gallery installation.
- App Intent execution from widget.
- Haptic feel.
- VoiceOver quality.
- Reduce Motion behavior.

Manual validation notes should include:

- Date.
- Device or simulator.
- OS version.
- Steps performed.
- Result.
- Any limitation.

## Visual Validation

Required visual checks:

- iPhone light mode main screen.
- iPhone dark mode main screen.
- iPhone settings.
- iPhone 7-day history.
- Goal reached state.
- Apple Watch main screen.
- Small widget.
- Medium widget if implemented.
- Dynamic Type large sizes.
- Reduce Motion enabled.

Acceptance:

- The glass remains the visual focus.
- Text does not overlap controls.
- Quick amount controls are tappable.
- Dark mode is not too neon or too low contrast.
- Generated assets contain no text or watermark.
- UI does not feel cartoonish, medical, or cluttered.

## Pause If Blocked

Pause and ask before continuing if:

- `xcodebuild -list` cannot find a project after Milestone 0.
- No iOS Simulator runtime is installed.
- The watchOS SDK or simulator runtime is missing and watch validation is required.
- HealthKit or App Group entitlements cannot be configured.
- CLI validation fails for reasons unrelated to the current milestone.
- Tests require real Apple framework permissions instead of mocks.

## Done When

Validation is done when `Scripts/validate-all.sh` passes all available checks, blocked platform checks are explicitly documented, manual validation notes cover Apple-only flows, and PROGRESS.md links each milestone to its validation result.
