# Aqualume Asset Manifest

## Policy

Do not generate assets until implementation reaches the asset milestone. This file defines the exact useful MVP assets and prompts.

Use Codex image generation with the imagegen skill where available. Generate final project-bound assets, then move selected outputs into the workspace and integrate them into the asset catalog. Do not leave referenced assets only under the default generated-images directory.

Motion should be implemented with SwiftUI/Canvas. Do not generate dozens of animation frames.

Avoid text embedded in generated images unless explicitly required.

## Asset Catalog Naming

Recommended asset catalog names:

- `AppIcon`
- `GlassHero`
- `WaterTextureAqua`
- `DropletCluster`
- `BackgroundLightAqua`
- `BackgroundDarkMoonwater`
- `WidgetBackgroundSmall`
- `WidgetBackgroundMedium`
- `ScreenshotBackgroundLight`
- `ScreenshotBackgroundDark`

## Generated MVP Assets

### 1. App Icon Source

Purpose: Source image for app icon variants.

Recommended output: 1024 x 1024 PNG.

Prompt:

```text
Use case: logo-brand
Asset type: iOS app icon source for Aqualume
Primary request: premium luminous app icon for a water drinking reminder app named Aqualume
Scene/backdrop: abstract soft aqua glow on a clean deep navy to pale aqua luminous background, no text
Subject: a single elegant translucent glass of water or refined water droplet, centered, instantly readable at small icon sizes
Style/medium: polished 3D icon render with Apple-native premium feel, not cartoon
Composition/framing: centered object, generous padding, square icon composition, strong silhouette
Lighting/mood: calm luxury, soft caustic highlights, frosted glass edges, subtle aqua light
Color palette: aqua, cyan, pale blue, deep navy, clean white highlights
Materials/textures: translucent glass, clear water, soft refraction, frosted rim
Constraints: no text, no letters, no logo watermark, no medical cross, no face, no harsh outline
Avoid: cartoon style, clutter, plastic look, busy background, advertising text
```

Acceptance:

- Recognizable at small size.
- No visible text.
- No medical or generic tracker cues.
- Works on light and dark Home Screen backgrounds.

### 2. Glass Hero

Purpose: Static premium glass artwork used as reference or layered visual in the main app. The actual fill animation should be SwiftUI/Canvas.

Recommended output: 1536 x 2048 PNG.

Prompt:

```text
Use case: product-mockup
Asset type: main SwiftUI hydration glass visual layer
Primary request: premium translucent empty drinking glass for a calm water reminder app
Scene/backdrop: clean minimal transparent-looking studio setup on a very pale aqua background without text
Subject: tall elegant empty glass, frosted rim, subtle thickness, refined highlights, no water fill
Style/medium: high-end product render, realistic glass, Apple-native polish
Composition/framing: portrait composition, glass centered, full object visible, generous padding
Lighting/mood: soft aqua rim light, gentle caustics, calm and luxurious
Color palette: clear glass, white highlights, pale aqua reflections
Materials/textures: translucent glass, frosted edges, subtle refraction, no heavy shadow
Constraints: no text, no logo, no hands, no straw, no fruit, no ice, no background clutter
Avoid: cartoon, medical tracker look, harsh black outlines, exaggerated distortion
```

Acceptance:

- Glass is empty and suitable for overlaying animated water.
- Edges are refined, not harsh.
- No extra objects.

### 3. Water Texture

Purpose: Subtle water fill texture for masking inside SwiftUI/Canvas.

Recommended output: 2048 x 2048 PNG.

Prompt:

```text
Use case: stylized-concept
Asset type: seamless-feeling water texture for masked SwiftUI fill
Primary request: luminous aqua water surface texture with soft caustics and gentle gradients
Scene/backdrop: abstract close-up water texture, no horizon, no container, no text
Subject: soft rippling aqua water and caustic highlights
Style/medium: refined realistic texture, premium app asset
Composition/framing: square tile-like composition, even detail distribution, no obvious focal object
Lighting/mood: calm luminous aqua light, moonlit freshness
Color palette: aqua, cyan, pale blue, white highlights, transparent-feeling depth
Materials/textures: liquid water, soft ripples, subtle caustics
Constraints: no text, no logo, no bubbles as large objects, no hard edges, no visible container
Avoid: noisy waves, ocean scene, pool tiles, cartoon water, harsh contrast
```

Acceptance:

- Can be masked inside the glass without looking like an ocean photo.
- Low contrast enough for readable overlays.

### 4. Droplet Cluster

Purpose: Decorative droplet accent for goal state, empty state, or marketing screenshots.

Recommended output: 1024 x 1024 PNG.

Prompt:

```text
Use case: stylized-concept
Asset type: decorative droplet cluster for Aqualume UI
Primary request: small elegant cluster of translucent aqua water droplets
Scene/backdrop: clean pale aqua studio background, no text
Subject: several refined water droplets with subtle refraction and tiny highlights
Style/medium: realistic polished 3D render, premium and restrained
Composition/framing: centered cluster with generous padding, droplets separated enough for clean cropping
Lighting/mood: soft aqua glow, calm, minimal
Color palette: clear water, pale aqua, white highlights
Materials/textures: transparent liquid, subtle refraction, no heavy shadow
Constraints: no text, no logo, no splash explosion, no cartoon shapes
Avoid: busy splash, harsh contrast, medical look, plastic beads
```

Acceptance:

- Droplets are subtle and premium.
- No splashy celebration tone.

### 5. Light Background

Purpose: Main app light mode background image or reference layer.

Recommended output: 2048 x 2732 PNG.

Prompt:

```text
Use case: productivity-visual
Asset type: iPhone app light mode background
Primary request: calm premium pale aqua background for a hydration app
Scene/backdrop: abstract soft white to pale aqua gradient with subtle caustic light and frosted depth
Subject: no main object, only background texture and light
Style/medium: refined digital background, Apple-native, minimal
Composition/framing: portrait, clean center area for a glass UI, very subtle edge depth
Lighting/mood: fresh morning light, calm and spacious
Color palette: warm white, pale aqua, soft cyan highlights
Materials/textures: frosted glass haze, barely visible water caustics
Constraints: no text, no logo, no objects, no strong vignette, no harsh lines
Avoid: stock photo look, beach scene, medical blue gradient, noisy texture
```

Acceptance:

- Does not compete with the glass.
- Works behind dark primary text.

### 6. Dark Background

Purpose: Main app dark mode background image or reference layer.

Recommended output: 2048 x 2732 PNG.

Prompt:

```text
Use case: productivity-visual
Asset type: iPhone app dark mode background
Primary request: calm moonlit dark background for a premium hydration app
Scene/backdrop: abstract deep navy water-light atmosphere with subtle aqua glow and soft caustics
Subject: no main object, only background texture and light
Style/medium: refined digital background, Apple-native, minimal
Composition/framing: portrait, clean center area for a glass UI, subtle depth at edges
Lighting/mood: moonlit water, quiet luxury, calm
Color palette: deep navy, blue-black, soft aqua glow, cool white glints
Materials/textures: frosted haze, subtle caustic reflections, liquid light
Constraints: no text, no logo, no objects, no stars, no ocean horizon
Avoid: space scene, neon cyberpunk, noisy texture, harsh gradients
```

Acceptance:

- Works behind light primary text.
- Feels premium, not neon.

### 7. Widget Background Small

Purpose: Small widget visual foundation.

Recommended output: 1024 x 1024 PNG.

Prompt:

```text
Use case: ui-mockup
Asset type: small WidgetKit background for Aqualume
Primary request: compact premium aqua liquid-glass widget background with no text
Scene/backdrop: abstract soft aqua glass and water-light background
Subject: no object except subtle liquid glass depth and soft highlight area
Style/medium: polished digital UI background, minimal Apple-native
Composition/framing: square, legible at small widget size, quiet center-left area for progress UI
Lighting/mood: calm luminous aqua, fresh, restrained
Color palette: pale aqua, cyan, white highlights, optional deep blue edge
Materials/textures: frosted glass, subtle caustics, liquid glow
Constraints: no text, no logo, no icons, no busy detail
Avoid: clutter, hard borders, medical dashboard feel
```

Acceptance:

- Supports overlaid SwiftUI text and progress.
- Does not contain fake UI controls.

### 8. Widget Background Medium

Purpose: Medium widget visual foundation.

Recommended output: 2048 x 1024 PNG.

Prompt:

```text
Use case: ui-mockup
Asset type: medium WidgetKit background for Aqualume
Primary request: wide premium aqua liquid-glass widget background with no text
Scene/backdrop: abstract soft aqua glass and moonlit water-light background
Subject: no object except subtle liquid glass depth, gentle caustics, and a quiet area for progress UI
Style/medium: polished digital UI background, minimal Apple-native
Composition/framing: wide landscape, balanced negative space for widget content
Lighting/mood: calm luminous aqua, refined, restrained
Color palette: aqua, pale cyan, soft white, optional deep navy gradient edge
Materials/textures: frosted glass, subtle caustics, liquid glow
Constraints: no text, no logo, no icons, no fake controls
Avoid: clutter, hard borders, noisy water, medical dashboard feel
```

Acceptance:

- Leaves room for progress UI and quick-add intent affordances.
- Works in both light and dark widget contexts or has separate variants if needed.

### 9. Screenshot Background Light

Purpose: App Store screenshot background for light composition.

Recommended output: 2160 x 3840 PNG.

Prompt:

```text
Use case: ads-marketing
Asset type: App Store screenshot background for Aqualume light theme
Primary request: premium portrait background for showcasing a hydration app screenshot
Scene/backdrop: luminous white to pale aqua liquid-glass environment with subtle caustics, no text
Subject: no product mockup, no phone, only background
Style/medium: high-end digital marketing background, refined and minimal
Composition/framing: portrait with clean central area for phone screenshot placement, subtle depth around edges
Lighting/mood: fresh, calm, luxurious, soft aqua light
Color palette: white, pale aqua, cyan highlights
Materials/textures: frosted glass haze, soft water caustics, subtle refraction
Constraints: no text, no logo, no phone, no hands, no objects
Avoid: stock beach imagery, hard gradients, clutter, medical blue
```

Acceptance:

- Suitable behind iPhone screenshot composites.
- No embedded text.

### 10. Screenshot Background Dark

Purpose: App Store screenshot background for dark composition.

Recommended output: 2160 x 3840 PNG.

Prompt:

```text
Use case: ads-marketing
Asset type: App Store screenshot background for Aqualume dark theme
Primary request: premium portrait dark background for showcasing a hydration app screenshot
Scene/backdrop: deep navy moonlit liquid-glass environment with subtle aqua caustics, no text
Subject: no product mockup, no phone, only background
Style/medium: high-end digital marketing background, refined and minimal
Composition/framing: portrait with clean central area for phone screenshot placement, subtle luminous edges
Lighting/mood: calm, luxurious, moonlit water, soft glow
Color palette: deep navy, blue-black, aqua highlights, cool white glints
Materials/textures: frosted glass haze, soft water caustics, subtle refraction
Constraints: no text, no logo, no phone, no hands, no objects
Avoid: cyberpunk neon, space scene, ocean horizon, clutter
```

Acceptance:

- Suitable behind dark-mode iPhone screenshot composites.
- No embedded text.

## Optional Assets After MVP

Generate only if implementation needs them:

- Additional glass highlight overlay.
- Separate dark-mode glass layer.
- App Store feature graphic.
- Onboarding illustration.
- Watch complication background.

## Integration Checklist

- Add selected images to the app asset catalog.
- Use stable asset names from this manifest.
- Provide 1x/2x/3x variants or single high-resolution PDF/PNG asset strategy as appropriate.
- Confirm images render in light and dark mode.
- Confirm generated images contain no unwanted text or watermark.
- Compress assets before release if file size is excessive.

## Pause If Blocked

Pause if:

- The generated app icon contains text, letters, medical symbols, or cartoon styling after one retry.
- Transparent cutout quality is required for glass or droplets and chroma-key removal produces poor edges. Ask before using CLI native transparency fallback.
- Asset catalog naming conflicts with an existing project asset.
- Generated assets make the UI feel busy or less Apple-native.

## Done When

Assets are done when every required MVP asset has a selected final file in the workspace, all are integrated into the asset catalog with stable names, previews have been visually checked in app surfaces, and PROGRESS.md records the prompts, chosen files, and validation notes.
