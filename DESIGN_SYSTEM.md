# Aqualume Design System

## Brand

Name: Aqualume

Tagline: Fill your day.

Aqualume should feel like a premium Apple-native utility: calm, spacious, precise, tactile, and quietly luminous.

## Visual Direction

Core style:

- Liquid glass.
- Soft aqua light.
- Frosted edges.
- Subtle caustics.
- Calm gradients.
- Premium translucent glass as the main object.

Avoid:

- Cartoon water.
- Medical tracker styling.
- Harsh outlines.
- Heavy shadows.
- Loud gamification.
- Busy dashboards.
- Text embedded in generated images unless explicitly needed.

## Color

Use semantic colors in SwiftUI first. Define named color assets only where stable brand colors are needed.

### Light Mode

- Background top: warm white, #FBFEFF.
- Background lower tint: pale aqua, #EAFBFF.
- Primary text: deep blue-black, #0D1B2A.
- Secondary text: desaturated blue-gray, #587084.
- Aqua primary: #55DDEB.
- Aqua deep: #1AA6B7.
- Water highlight: #B9F6FF.
- Glass edge: white with opacity.
- Success glow: aqua-mint, #7FFFD4.

### Dark Mode

- Background top: deep navy, #07111F.
- Background lower tint: moonlit blue, #0B2038.
- Primary text: cool white, #F2FBFF.
- Secondary text: soft blue-gray, #A7BBCB.
- Aqua primary: #42D9E8.
- Aqua deep: #0A8FA3.
- Water highlight: #8EF4FF.
- Glass edge: pale aqua with opacity.
- Success glow: soft cyan, #5DE8D5.

## Typography

Use Apple-native system typography.

- Large numeric readout: rounded or default system, bold or semibold, large and readable.
- Section titles: system semibold.
- Body text: system regular.
- Captions: system regular or medium.
- Avoid custom fonts for MVP unless a clear platform-native issue appears.

Guidelines:

- Keep text minimal.
- Use large numbers for progress.
- Do not place explanatory paragraphs on the main screen.
- Keep watchOS copy especially short.

## Layout

### iPhone Main Screen

Hierarchy:

1. Daily progress readout.
2. Large interactive glass.
3. Quick amount controls.
4. Undo and secondary actions.
5. History preview or navigation.

Layout rules:

- The glass should be visually dominant and centered.
- Keep generous vertical spacing.
- Do not wrap the primary experience in a decorative card.
- Quick amounts may use compact capsule buttons or a segmented control style.
- Undo can be a subtle button near the latest-log feedback area.
- Settings should be reachable through a toolbar button.

### Apple Watch

Hierarchy:

1. Compact glass progress.
2. Current amount or percent.
3. Tap target for default add.
4. Quick amount controls if space allows.

Rules:

- Prioritize tap accuracy.
- Avoid small dense controls.
- Keep animations short and battery-conscious.

### Widget

Widget should communicate:

- Current progress.
- Amount logged today.
- Goal state.
- Quick-add affordance where supported.

Rules:

- No dense text.
- Use the same luminous water language as the app.
- Make small widget states legible.

## Main Glass

The glass is the signature object.

Requirements:

- Premium translucent material.
- Frosted rim and subtle highlights.
- Water line fills upward based on progress.
- Water should have a gentle meniscus or curved edge.
- Motion uses SwiftUI/Canvas, not generated animation frames.
- Generated assets can provide texture, highlights, droplets, and static background layers.

Interaction states:

- Idle: calm, slowly alive if Reduce Motion is off.
- Pressed: subtle scale or light response.
- Logging: water rise, ripple, floating amount label.
- Goal reached: calm glow and small bubbles.
- Reduce Motion: simplified progress update with minimal movement.

## Motion

Motion should be slow, restrained, and physically plausible.

Durations:

- Tap press response: 0.10-0.18 seconds.
- Water rise after logging: 0.45-0.80 seconds.
- Ripple: 0.60-1.00 seconds.
- Floating amount label: 0.90-1.30 seconds.
- Goal glow: 1.20-2.00 seconds.

Easing:

- Use easeOut or spring with low bounce.
- Avoid aggressive bounce.
- Avoid sudden flashes.

Respect accessibility:

- If Reduce Motion is enabled, remove ripple and bubble motion.
- Use opacity and static progress changes instead.

## Haptics

Use subtle haptics:

- One-tap log: light impact.
- Undo: selection or soft impact.
- Goal reached: gentle success notification.

Do not overuse haptics for every minor state update.

## Components

### HydrationGlassView

Responsibilities:

- Render glass shell.
- Render water fill progress.
- Render optional ripple and goal glow.
- Expose tap action.
- Accept progress, state, unit display, and accessibility label.

No persistence, HealthKit, reminders, or sync logic in this view.

### QuickAmountControl

Requirements:

- Shows 100 ml, 250 ml, 330 ml, 500 ml or converted oz labels.
- Large enough for comfortable tapping.
- Uses brand aqua accents without dominating the glass.

### ProgressReadout

Requirements:

- Shows today's total and daily goal.
- Uses large readable numbers.
- Handles ml/L and oz.

### HistoryMiniChart

Requirements:

- Shows 7 days.
- Minimal bars or liquid marks.
- Highlights today.
- Avoid complex chart controls.

### Settings Rows

Requirements:

- Apple-native Form or grouped style.
- Clear labels.
- No custom decorative panels unless needed.

## Copy Tone

Use calm, brief, encouraging copy.

Examples:

- "Fill your day."
- "Goal reached."
- "A little more light in the glass."
- "Reminder added."

Avoid:

- "You failed."
- "Behind schedule."
- "Streak broken."
- "Drink now!"

## App Icon Direction

The icon should feel premium and simple:

- A luminous translucent glass or water droplet.
- Aqua light on a deep or pale background.
- No tiny text.
- No medical cross.
- No cartoon face.
- Legible at small sizes.

## Asset Usage Rules

- Use generated bitmap assets for static premium texture, icon, background, and marketing backgrounds.
- Use SwiftUI and Canvas for progress animation, water level, ripples, bubbles, and state changes.
- Keep generated images out of business logic.
- Integrate final assets into asset catalogs with stable names from ASSET_MANIFEST.md.

## Done When

Design implementation is done when the app visually matches this direction in light mode, dark mode, iPhone, Apple Watch, and widgets; supports Dynamic Type and Reduce Motion; and no primary UI surface feels cluttered, cartoonish, or medical.
