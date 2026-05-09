# Aqualume Product Specification

## Product

Aqualume is a premium water drinking reminder app for iPhone and Apple Watch.

Tagline: Fill your day.

The core interaction is a large, beautiful glass of water. The glass starts empty each day and fills as the user logs water. Tapping the glass logs the user's default amount. The app should feel calm, luxurious, Apple-native, and extremely polished.

## Product Principles

- Calm, luxurious, and encouraging.
- Apple-native interactions, layout, typography, animation, haptics, and accessibility.
- Minimal text and low clutter.
- The glass is the primary interface, not a decorative illustration.
- Progress should feel rewarding without becoming noisy.
- The app must never shame, scold, or create a medical tracker tone.

## MVP Scope

The MVP must include:

- iOS SwiftUI app.
- watchOS companion app.
- Main iOS screen with animated filling glass.
- Main watchOS screen with compact filling glass and one-tap logging.
- One-tap logging from the main glass.
- Quick amounts: 100 ml, 250 ml, 330 ml, 500 ml.
- Configurable default logging amount.
- Undo latest log.
- Daily hydration goal.
- Units: ml/L and oz.
- Local persistence.
- Local reminder scheduling.
- HealthKit write support for dietary water.
- WatchConnectivity sync between iPhone and Apple Watch.
- Small 7-day history.
- Settings.
- WidgetKit widget with App Intent quick-add.
- Generated visual assets for app icon, glass, water texture, droplets, backgrounds, widgets, and App Store screenshot backgrounds.

## Non-Goals For MVP

- No social features.
- No cloud accounts.
- No AI drink recognition.
- No complex nutrition tracking.
- No ads.
- No weather-based adaptive goals.
- No complicated beverage hydration multipliers.
- No subscription or paywall requirement. StoreKit architecture may be stubbed only if useful.

## Core UX Requirements

### Daily Reset

- Each local calendar day starts with an empty glass.
- Today's total is the sum of logs for the current local day.
- History must retain past days and not mutate when the current day resets.
- Time zone changes should use Calendar.current at read/write boundaries.

### Main Screen

- The glass is centered and visually dominant.
- The glass fill level maps to daily progress:
  - 0 percent at 0 intake.
  - 100 percent at daily goal.
  - Values above goal may be represented as a full glass with a calm completed state.
- The primary numeric readout shows today's total and goal.
- A secondary progress cue may show percentage or remaining amount.
- Quick amount controls are available without leaving the main screen.
- Undo latest log is visible or reachable after logging.

### Logging

- Tapping the glass logs the default amount.
- Quick amounts log the selected amount immediately.
- After a successful log:
  - Animate water rising.
  - Show a ripple.
  - Show a floating "+250 ml" style label using the actual amount and current unit.
  - Trigger subtle haptic feedback.
- Logging must persist locally before UI treats it as committed.
- If HealthKit write fails, local logging still succeeds and the app surfaces a non-blocking status.

### Goal Completion

- When the daily goal is reached for the first time that day, show a calm glow and small bubbles.
- Do not use loud confetti, flashing, harsh color, or competitive language.
- Copy should be encouraging and restrained.

### Undo

- Undo latest log reverses the most recent local hydration entry for the current day.
- Undo should also attempt to reverse or reconcile HealthKit writes when possible.
- If exact HealthKit deletion is not available in the chosen implementation, document the limitation in code and avoid misleading UI.
- Undo should sync to watchOS and widgets through the shared state path.

### Units

- Storage canonical unit: milliliters.
- Display units:
  - Metric: ml for amounts under 1000 ml, L for larger summary values when appropriate.
  - Imperial: oz rounded to sensible display precision.
- Unit changes affect display, quick labels, goal display, and App Intent copy.
- Unit changes must not rewrite stored history.

### Settings

Settings must include:

- Daily goal.
- Default logging amount.
- Unit preference.
- Reminder enable/disable.
- Reminder schedule controls.
- HealthKit authorization status and action.
- About app section with name and tagline.

### Reminders

- Use local UserNotifications.
- Reminder scheduling is isolated in a scheduler service.
- The app should request notification permission only when the user enables reminders or explicitly starts setup.
- Reminder copy should be calm and nonjudgmental.

### HealthKit

- Write dietary water samples.
- HealthKit logic is isolated in a service.
- App must handle unavailable HealthKit, denied permission, partial authorization, and write failures.
- HealthKit is not the source of truth for MVP; local persistence is.

### Watch App

- The watch app supports:
  - Current daily progress.
  - One-tap default amount logging.
  - Quick amount logging if layout allows.
  - Goal completion calm state.
  - Sync with iPhone through WatchConnectivity.
- watchOS should remain usable when the phone is temporarily unreachable by persisting local pending logs and syncing later.

### Widget

- WidgetKit widget shows today's progress.
- App Intent quick-add supports default amount and/or fixed quick amounts.
- Widget uses shared persistence or an app group path chosen during implementation.
- Widget UI should match the calm liquid glass direction.

## Data Model

Canonical values use milliliters.

Recommended entities:

- HydrationLog:
  - id
  - amountML
  - loggedAt
  - source: iPhone, watch, widget, appIntent
  - healthKitSampleIdentifier optional
  - syncState optional
- DailyHydrationSummary:
  - dateKey
  - totalML
  - goalML
  - reachedGoalAt optional
- UserSettings:
  - dailyGoalML
  - defaultAmountML
  - unitSystem
  - remindersEnabled
  - reminderSchedule
  - healthKitEnabled
- PendingSyncEvent:
  - id
  - eventType
  - payload
  - createdAt
  - retryCount

SwiftData should be used if available for the selected deployment target. Otherwise, keep persistence behind repository protocols so storage can change without rewriting views.

## Architecture Requirements

- SwiftUI for all app UI.
- Use MVVM or a lightweight observable state architecture.
- Keep business logic out of views.
- Use testable services and protocols.
- Isolate HealthKit in a service.
- Isolate UserNotifications in a scheduler.
- Isolate WatchConnectivity in a sync service.
- Isolate WidgetKit and AppIntents from main app views.
- StoreKit architecture may be stubbed but is not required for MVP.
- Prefer dependency injection through initializers, environment values, or composition roots.
- Avoid singleton-heavy business logic except where Apple framework delegates require a bridge.

Recommended modules or folders:

- AqualumeApp
- Features/Home
- Features/History
- Features/Settings
- Domain
- Persistence
- Services/HealthKit
- Services/Notifications
- Services/Sync
- SharedUI
- Widgets
- WatchApp
- Tests
- Scripts

## Accessibility

- Dynamic Type support for text.
- VoiceOver labels for glass, progress, quick amounts, undo, and settings controls.
- Reduce Motion support:
  - Replace water rise and ripple with a simpler opacity/progress transition.
- Sufficient contrast in light and dark mode.
- Haptics must not be required to understand state.
- App Intent actions should be accessible from widgets and Shortcuts where possible.

## Acceptance Criteria

- iOS app compiles and launches.
- watchOS app compiles and launches.
- Widget target compiles if created.
- User can log water from iOS main screen with one tap.
- User can log water from Apple Watch.
- User can log quick amounts of 100 ml, 250 ml, 330 ml, and 500 ml.
- User can undo the latest current-day log.
- Daily total persists across launch.
- Daily glass starts empty on a new local day.
- Unit preference changes display without corrupting stored data.
- Reminder scheduling is local and isolated.
- HealthKit write support is implemented behind a service and handles permission states.
- WatchConnectivity sync moves logs between iPhone and watch.
- Widget shows current progress and supports quick-add through App Intent.
- 7-day history is visible.
- Main UI supports light and dark mode.
- Main UI meets the design direction in DESIGN_SYSTEM.md.

## Pause If Blocked

Pause and ask before continuing if:

- Xcode or the selected iOS/watchOS SDK is unavailable.
- Apple platform capabilities require a paid developer team or entitlement that cannot be configured locally.
- HealthKit, App Groups, WatchConnectivity, or Widget capabilities cannot be enabled in the project.
- A generated asset is unsuitable for the premium glass style after one focused regeneration attempt.
- The selected minimum deployment target prevents SwiftData, AppIntents, WidgetKit, or watchOS requirements from working as planned.
- Existing user changes conflict with the implementation plan.

## Done When

The MVP is done when all acceptance criteria in this spec pass, validation commands in VALIDATION.md succeed or have documented platform-limitation notes, and PROGRESS.md shows every implementation milestone completed with dates and verification notes.
