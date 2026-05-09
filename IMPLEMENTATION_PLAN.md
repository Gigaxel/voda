# Aqualume Implementation Plan

## Rule

Do not start implementation until the user runs `/goal` or explicitly asks to begin a milestone. This document is the execution plan only.

Each milestone should be implemented, validated, and recorded in PROGRESS.md before moving to the next milestone.

## Milestone 0: Project Setup

Goal: Create the base Xcode project and target structure.

Tasks:

- Create an iOS SwiftUI app target named Aqualume.
- Add a watchOS companion target.
- Add a WidgetKit extension target.
- Add unit test targets.
- Add shared groups/folders for Domain, Persistence, Services, SharedUI, Features, Widgets, WatchApp, and Scripts.
- Decide minimum deployment targets for iOS and watchOS.
- Add app capabilities needed for HealthKit, WatchConnectivity, notifications, widgets, and App Groups where required.

Acceptance:

- Xcode project opens.
- `xcodebuild -list` shows expected schemes.
- iOS app target compiles with placeholder SwiftUI view.
- watchOS target compiles with placeholder SwiftUI view.
- Widget target compiles with placeholder widget if created in this milestone.

Validation:

- Follow VALIDATION.md "Project Discovery".
- Follow VALIDATION.md "Build iOS".
- Follow VALIDATION.md "Build watchOS".

Pause if blocked:

- Xcode CLI tools are missing.
- watchOS SDK is unavailable.
- Required capabilities cannot be added locally.

## Milestone 1: Domain Model And Hydration Logic

Goal: Build testable hydration rules independent of UI and Apple frameworks.

Tasks:

- Define HydrationLog.
- Define user settings model.
- Define unit conversion helpers.
- Define date-key logic for daily summaries.
- Implement hydration calculation service.
- Implement undo latest current-day log behavior.
- Add unit tests for:
  - Add log.
  - Quick amount values.
  - Daily total.
  - New day reset behavior.
  - Over-goal progress clamp/display.
  - Undo latest log.
  - ml/L and oz display conversion.

Acceptance:

- Business logic has no SwiftUI dependency.
- Unit tests pass from CLI.
- Canonical storage is milliliters.

Validation:

- Run unit test commands in VALIDATION.md.

Pause if blocked:

- Date/time behavior is ambiguous for time zones or day boundaries.

## Milestone 2: Persistence Repository

Goal: Persist logs and settings locally behind protocols.

Tasks:

- Define HydrationRepository protocol.
- Define SettingsRepository protocol.
- Implement SwiftData storage if available for the chosen deployment target.
- Provide fallback or in-memory implementation for tests.
- Add repository tests.
- Add migration/version notes if needed.

Acceptance:

- Logs persist across app launch.
- Settings persist across app launch.
- Tests can inject in-memory repositories.
- UI code does not know whether SwiftData or another storage backend is used.

Validation:

- Run unit tests.
- Build iOS.

Pause if blocked:

- SwiftData is unavailable for selected deployment target. Switch to repository-backed alternative and document the decision.

## Milestone 3: Observable App State

Goal: Create the app state layer that coordinates repositories and UI models.

Tasks:

- Add HydrationViewModel or lightweight observable state object.
- Expose today's total, progress, goal, unit labels, quick amounts, and undo availability.
- Wire log, quick-add, undo, and settings update actions.
- Keep HealthKit, notifications, and sync behind protocols but stubbed.
- Add state-level tests.

Acceptance:

- Views can bind to one state object without business logic.
- Logging updates state and persists.
- Undo updates state and persists.
- Unit changes update labels.

Validation:

- Run unit tests.
- Build iOS.

Pause if blocked:

- State starts duplicating domain logic instead of calling domain services.

## Milestone 4: iOS Main UI

Goal: Build the polished main SwiftUI experience.

Tasks:

- Implement ProgressReadout.
- Implement HydrationGlassView with animated fill using SwiftUI/Canvas.
- Implement tap-to-log.
- Implement QuickAmountControl.
- Implement undo latest log.
- Implement floating amount label.
- Implement ripple and subtle haptics.
- Implement goal glow and bubbles.
- Support light mode, dark mode, Dynamic Type, VoiceOver, and Reduce Motion.

Acceptance:

- Tapping the glass logs the default amount.
- Quick amounts log correctly.
- Water level animates upward.
- Undo works from the main screen.
- Goal reached state is calm.
- No business logic lives in views.

Validation:

- Build iOS.
- Run unit tests.
- Optional local UI smoke test if a UI test target exists.

Pause if blocked:

- The glass interaction feels cluttered, cartoonish, or visually weak. Revisit DESIGN_SYSTEM.md before adding features.

## Milestone 5: Settings And History

Goal: Add required configuration and 7-day history.

Tasks:

- Build Settings screen.
- Add daily goal editing.
- Add default amount editing.
- Add unit preference.
- Add reminder controls placeholder wired to scheduler protocol.
- Add HealthKit status/action placeholder wired to service protocol.
- Add 7-day history component.

Acceptance:

- Settings persist.
- History shows last 7 local days.
- Unit changes affect main screen, history, and quick labels.
- Settings UI is Apple-native and uncluttered.

Validation:

- Build iOS.
- Run unit tests.

Pause if blocked:

- Settings create invalid goals or default amounts. Add validation before continuing.

## Milestone 6: Notifications

Goal: Implement local reminder scheduling.

Tasks:

- Implement NotificationScheduler protocol.
- Request authorization only from explicit user action.
- Schedule local reminders based on settings.
- Cancel reminders when disabled.
- Add tests for scheduling decisions using a mock scheduler where possible.

Acceptance:

- Enabling reminders schedules local notifications.
- Disabling reminders cancels pending reminders.
- Notification copy is calm and nonjudgmental.
- Notification code is isolated from views.

Validation:

- Build iOS.
- Run unit tests.

Pause if blocked:

- Notification permission behavior cannot be validated in CLI. Document manual simulator validation steps in PROGRESS.md.

## Milestone 7: HealthKit

Goal: Add dietary water write support.

Tasks:

- Implement HealthKit service protocol.
- Request HealthKit authorization from Settings or first explicit enable action.
- Write dietary water samples after successful local logs.
- Store sample identifiers if feasible.
- Handle unavailable, denied, and failed writes.
- Add service tests with mock implementation.

Acceptance:

- Local logging succeeds even if HealthKit write fails.
- HealthKit errors are non-blocking and visible enough for debugging.
- HealthKit code is isolated from views and domain logic.

Validation:

- Build iOS with HealthKit capability.
- Run unit tests.
- Document manual Health app validation if CLI cannot verify sample writes.

Pause if blocked:

- HealthKit entitlement or simulator support is unavailable.

## Milestone 8: Watch App And Sync

Goal: Add watchOS logging and WatchConnectivity sync.

Tasks:

- Implement WatchConnectivity sync service protocol.
- Add iOS sync coordinator.
- Add watchOS local state and pending event queue.
- Build watch main UI with compact glass.
- Support one-tap default logging from watch.
- Support quick amounts if space allows.
- Reconcile logs between phone and watch.

Acceptance:

- Watch app compiles.
- Watch can log water.
- iPhone receives watch logs when reachable.
- Watch handles temporary unreachable state with pending logs.
- Duplicate logs are avoided using stable IDs.

Validation:

- Build iOS.
- Build watchOS.
- Run unit tests.
- Document any manual paired-simulator validation steps.

Pause if blocked:

- Paired simulator setup is unavailable or WatchConnectivity cannot be exercised locally.

## Milestone 9: Widget And App Intent

Goal: Add WidgetKit widget and quick-add App Intent.

Tasks:

- Add shared app group persistence path if needed.
- Build small widget progress UI.
- Build medium widget progress UI if MVP scope allows.
- Add App Intent for quick add default amount.
- Add App Intent for fixed quick amounts if feasible.
- Refresh widget timelines after logs.

Acceptance:

- Widget target compiles.
- Widget shows today's progress.
- App Intent quick-add writes a log through the shared logic path.
- Widget UI matches Aqualume design.

Validation:

- Build widget target.
- Build iOS.
- Run unit tests.
- Document manual widget and App Intent validation.

Pause if blocked:

- App Group or App Intent configuration cannot be completed locally.

## Milestone 10: Asset Generation And Integration

Goal: Generate and integrate MVP visual assets from ASSET_MANIFEST.md.

Tasks:

- Generate MVP assets using the manifest prompts.
- Save selected final assets into the workspace.
- Integrate assets into asset catalogs.
- Wire backgrounds, icon source, water texture, droplet accents, and screenshot backgrounds.
- Verify images contain no text, watermark, medical symbols, or cartoon style.

Acceptance:

- Required MVP assets are present.
- Asset names match ASSET_MANIFEST.md.
- Main UI still uses SwiftUI/Canvas for motion.
- Light and dark surfaces render cleanly.

Validation:

- Build iOS.
- Build watchOS.
- Build widget target.
- Perform visual checks on key screens.

Pause if blocked:

- Image generation is unavailable.
- A required asset needs true native transparency and built-in chroma-key removal is insufficient.

## Milestone 11: Polish, Accessibility, And Release Validation

Goal: Bring the MVP to a polished, testable state.

Tasks:

- Review light mode, dark mode, Dynamic Type, VoiceOver, and Reduce Motion.
- Refine animation timing and haptics.
- Add missing tests for high-risk logic.
- Add CLI validation scripts.
- Run complete validation suite.
- Update PROGRESS.md with final status.

Acceptance:

- All MVP requirements pass.
- CLI validation succeeds or documents platform limitations.
- UI matches DESIGN_SYSTEM.md.
- PROGRESS.md is current.

Validation:

- Run all commands in VALIDATION.md.

Pause if blocked:

- Any release-critical validation fails without a known fix.

## Done When

Implementation is done when Milestones 0 through 11 are complete, all acceptance criteria in AQUALUME_SPEC.md pass, all required assets from ASSET_MANIFEST.md are integrated, VALIDATION.md commands pass or document unavoidable Apple-platform limitations, and PROGRESS.md has milestone-by-milestone completion notes.
