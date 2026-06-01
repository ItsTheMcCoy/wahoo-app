# Wahulo: Marble Mayham — Asset Design Guide

This document defines the complete visual design system for Wahulo: Marble Mayham. Provide it verbatim to any AI asset-generation session to ensure new assets match the existing game.

---

## Game Identity

**Title:** Wahulo: Marble Mayham  
**Genre:** Browser-based board game (marble race for 4 players)  
**Physical world analogy:** A well-worn hardwood game board sitting on a dark tabletop, viewed from above in warm ambient light. The aesthetic is classic and tactile — like a quality family board game from the 1970s, rendered with modern lighting.  
**Tone:** Warm, physical, slightly whimsical, but not cartoonish, not photorealistic. The board should feel like wood you could touch with detailed wood grain pattern and a matte finish. Marbles should be as realistic as possible and feel like glass you could roll.  The overall game should mix modern and vintage sytles well.
**Asset Sytle** Marbles should look as realistic as possible.

---

## Color Palette

All hex values are derived directly from the game's GDScript source. Use these exact values.

### Player Marble Colors

| Player | Name   | Primary Hex | Use                        |
|--------|--------|-------------|----------------------------|
| 0      | Red    | `#db332b`   | Marble fill, base zone tint |
| 1      | Green  | `#299945`   | Marble fill, base zone tint |
| 2      | Yellow | `#edbf2b`   | Marble fill, base zone tint |
| 3      | Blue   | `#2b57c7`   | Marble fill, base zone tint |

Player label text uses the primary color darkened by ~28% (`color.darkened(0.28)`):

| Player | Label Text Hex |
|--------|---------------|
| Red    | `#9e2420`     |
| Green  | `#1d6c31`     |
| Yellow | `#a9891f`     |
| Blue   | `#1f3e8f`     |

Base zone spot color = primary color blended 52% toward board wood (`#917049`):

| Player | Zone Fill Hex (approx) |
|--------|----------------------|
| Red    | `#a3756e`            |
| Green  | `#5b8c6a`            |
| Yellow | `#b3a369`            |
| Blue   | `#6778a6`            |

### Cuurent Board Surface

| Role                | Hex         | Opacity | Notes                                      |
|---------------------|-------------|---------|---------------------------------------------|
| Board base fill     | `#917049`   | 100%    | Warm mid-tone oak                           |
| Board inner lighter | `#c4a882`   | 80%     | Interior field, slightly lighter than edge  |
| Board outer edge    | `#241c14`   | 100%    | Dark walnut frame                           |
| Wood grain dark     | `#543d29`   | 20%     | Subtle dark grain lines                     |
| Wood grain light    | `#dbbd96`   | 12%     | Subtle light grain lines                    |
| Edge vignette       | `#140f0a`   | 23%     | Corners darken to frame the board           |
| Ambient occlusion   | `#120d08`   | 12%     | Depth shadow under/around spots             |

## Board Surface Notes: The current board surface feels pretty plain.  Use the above as a general guide, but let's make the board surface look more realistic.  With visible wood grain.

### Track Elements

| Role                | Hex         | Notes                                      |
|---------------------|-------------|---------------------------------------------|
| Track path dark     | `#57422b`   | Outer edge of the loop path                |
| Track path light    | `#ba9c75`   | Inner highlight of the loop path            |
| Track cell fill     | `#e0ccab`   | Ivory/cream — standard board position spots |
| Track cell edge     | `#403326`   | Dark border ring around each spot           |
| Spot cavity shadow  | `#33261c`   | 24% — depth cue below/behind each spot      |
| Center hole fill    | `#523d2b`   | Deep brown — the center shortcut hole       |
| Center hole edge    | `#1f1712`   | Very dark border around center hole         |

### Marble Rendering

| Role                | Hex / Value        | Notes                                      |
|---------------------|-------------------|--------------------------------------------|
| Marble edge ring    | `#1a1712`         | Thin dark outline around marble            |
| Marble specular     | `#ffffff` @ 48%   | Top-left sparkle dot                       |
| Marble rim light    | Player color + 50% white @ 35% | Subtle arc along upper-left rim |
| Move source ring    | `#fff78c` @ 95%   | Yellow-white glow: marble you can pick up  |
| Move destination    | `#ffc71a` @ 100%  | Amber ring: where a marble can go          |
| Shadow (grounded)   | `#080808` @ 24%   | Soft drop shadow below marble at rest      |
| Shadow (lifted)     | `#080808` @ 10%   | Faded shadow when marble is mid-animation  |

Marble sphere shading (center light source at ~35% X, 28% Y):
- Lower-right quadrant darkened to ~70% of base color
- Upper-left quadrant lightened to ~24% blend toward white
- Rim highlight arc on upper-left edge: base color + 50% white, 35% opacity

### UI Chrome

| Role                    | Hex         | Opacity | Notes                              |
|-------------------------|-------------|---------|------------------------------------|
| Panel background        | `#2b211a`   | 94%     | All floating panels (setup, win)   |
| Panel border            | `#75573d`   | 95%     | Warm sienna panel border           |
| Die frame background    | `#402e1f`   | 96%     | Slightly richer than panel         |
| Die frame border        | `#b38a61`   | 98%     | Warm gold — die is the focal point |
| Board frame background  | `#1a140f`   | 90%     | Very dark surround for board area  |
| Board frame border      | `#6b4d33`   | 98%     | Mid-brown board bezel              |
| Status log background   | `#211a14`   | 72%     | Semi-transparent log area          |
| Status log border       | `#6e523b`   | 88%     | Warm brown, slightly dim           |

### Text Colors

| Role                 | Hex         | Opacity | Notes                             |
|----------------------|-------------|---------|-----------------------------------|
| Status log body text | `#f7ebd6`   | 100%    | Warm off-white, high contrast     |
| Turn label           | `#faf2e0`   | 100%    | Very light warm cream             |
| Turn label outline   | `#140f0d`   | 92%     | Near-black outline for legibility |
| Die face             | `#faf2e0`   | 100%    | Same as turn label                |
| Die outline          | `#1a120d`   | 95%     | Slightly deeper than turn outline |
| Menu normal text     | `#f2e6d1`   | 100%    | Slightly warmer cream             |
| Menu hover text      | `#fff7e0`   | 100%    | Almost white, warm                |
| Menu disabled text   | `#a19485`   | 100%    | Desaturated mid-tone grey         |
| Button label text    | `#f7eddb`   | 100%    | Warm cream                        |

### Buttons

| State    | Background | Border    | Notes                          |
|----------|------------|-----------|--------------------------------|
| Normal   | `#4d3826`  | `#ba8f63` | Mid dark brown / gold border   |
| Hover    | `#614730`  | `#ba8f63` | Slightly lighter brown         |
| Pressed  | `#38291c`  | `#ba8f63` | Darker than normal             |
| Disabled | `#30261f`@ 74% | `#695747` @ 74% | Muted, desaturated  |

### Loading Screen / App Chrome

| Role                  | Hex       | Notes                            |
|-----------------------|-----------|----------------------------------|
| Page background       | `#1e160e` | Very dark warm brown             |
| Game title ("Wahulo") | `#c8922a` | Gold / amber serif               |
| Subtitle text         | `#75573d` | Muted brown, letter-spaced       |
| Loading label text    | `#4a3020` | Dark brown, barely visible       |
| Progress bar start    | `#8a5a18` | Dark amber                       |
| Progress bar mid      | `#c8922a` | Same as title gold               |
| Progress bar end      | `#e8b84a` | Lighter amber highlight          |
| Error box background  | `#3a1a1a` | Dark red-brown                   |
| Error box border      | `#8a3030` | Deep red                         |

---

## Existing Texture Assets

### `board_wood.svg` (1024×1024)

A procedural wood texture used as a soft overlay on the board surface at 72% opacity. Key characteristics:
- **Base gradient** (top → bottom): `#8f6b48` → `#7a593b` → `#694b31` — medium oak to dark walnut
- **Dark grain lines** (wavy horizontal paths): `#4a341f` @ 26% and 20% opacity
- **Light grain lines** (wavy horizontal paths): `#d6bc9b` @ 18% and 16% opacity
- **Edge corner shadow gradient**: `#2c1c10` @ 34% opacity, diagonal
- **Top-center radial highlight**: `#f4dcc0` @ 18% — simulates overhead light source
- **Center warm glow**: `#c8a279` @ 34% radial — depth/warmth in the middle
- **Long sweeping grain strokes** at 24% overall opacity: `#3c2818` (dark) and `#d5b892` (light)
- Grain has a gentle sway/wave — not straight lines. The pattern repeats at 64px and 48px tiles.

### `marble_gloss.svg` (256×256)

A grayscale gloss mask applied on top of the player-colored marble circles. It is tinted with the player color at draw time. Key characteristics:
- **Sphere shading gradient** (cx=35%, cy=28%, r=70%): white @ 95% → near-white @ 85% → light grey @ 88% → dark grey @ 100% — simulates a light source at upper-left
- **Specular highlight 1** (ellipse at 90,80, rx=40, ry=30): white @ 95% → transparent — primary hotspot
- **Specular highlight 2** (ellipse at 164,170, rx=32, ry=18): white @ 26% → transparent — secondary softer highlight at lower-right
- **Rim shade gradient** (cx=52%, cy=62%, r=58%): black @ 0% (inside) → black @ 26% (outer edge) — darkens the rim
- **Interior wisp lines** at 26% opacity: light `#ffffff` strokes simulating subsurface scatter / lustre
- The file is grayscale/white — it gets its color from the player color applied at render time

---

## Asset Manifest

### Currently Exist

| File                              | Type | Size    | Status   |
|-----------------------------------|------|---------|----------|
| `godot/assets/textures/board_wood.svg`            | SVG | 1024×1024 | In use |
| `godot/assets/textures/marble_gloss.svg`          | SVG | 256×256   | In use |
| `godot/assets/textures/wahulo_wordmark.svg`       | SVG | 1400×520  | In use — loading screen |
| `godot/assets/textures/background_felt_tile_512.svg` | SVG | 512×512 | In use — loading screen background |
| `godot/build/web/og_preview.png`                  | PNG | 1200×630  | Place manually — see below |
| `godot/build/web/index.icon.png`                  | PNG | 32×32     | Replace with branded favicon |
| `godot/build/web/index.apple-touch-icon.png`      | PNG | 180×180   | Replace with branded touch icon |
| `godot/build/web/index.png`                       | PNG | 800×450   | Replace with branded boot splash |
| `godot/assets/textures/boot_splash.png`           | PNG | 800×450   | Source boot splash for Godot project settings |

### Pending Manual Placement

These PNG files have been created and must be copied to the locations below. Godot exports will overwrite `index.icon.png`, `index.apple-touch-icon.png`, and `index.png` — set them in Godot project settings first so re-exports use the branded versions.

| Save as…                                         | Size    | Content                              |
|--------------------------------------------------|---------|--------------------------------------|
| `godot/build/web/og_preview.png`                 | 1200×630 | Social/OG preview image             |
| `godot/build/web/index.icon.png`                 | 32×32   | Favicon (cropped from app icon)      |
| `godot/build/web/index.apple-touch-icon.png`     | 180×180 | iOS touch icon                       |
| `godot/build/web/index.png`                      | 800×450 | Boot splash shown by Godot on load   |
| `godot/assets/textures/boot_splash.png`          | 800×450 | Same boot splash, source copy        |
| `godot/icon.png`                                 | 512×512 | App icon (also update `project.godot` to reference it) |

To wire the boot splash in Godot: open Project Settings → Application → Boot Splash → set Image to `res://assets/textures/boot_splash.png`.
To wire the app icon: open Project Settings → Application → Config → Icon, set to `res://icon.png`.

---

## Style Rules

### DO
- Use warm tones everywhere. All neutrals should read as warm grey-brown, not cool grey.
- Ground everything in a physical material: wood, glass, felt, brass, ivory.
- Use radial gradients to simulate a single warm overhead light source (top-center to upper-left).
- Add subtle grain or texture to flat surfaces — nothing should look perfectly uniform.
- Marble highlights are offset to upper-left (light at ~35% X, 28% Y).
- Board grain lines wave gently — organic, not ruler-straight.
- Borders and edges darken away from the light (bottom/right edges slightly darker).
- Text on dark backgrounds: warm cream (`#f7ebd6` family). Text on light surfaces: deep brown.
- Shadow color is near-black with a warm brown cast (`#080808` to `#140f0a`), never pure black.

### DON'T
- No cool blues, pure whites, or neutral greys in backgrounds or fills.
- No flat/solid colors without at least a hint of gradient or texture.
- No heavy drop shadows that look digitally generic — shadows should be soft and warm.
- No neon, no glows beyond the subtle amber of move indicators.
- No UI chrome that looks like a web app (flat design, material design, etc.) — everything should feel physical.
- Don't make marbles flat circles — they must read as spheres with highlights and shading.
- Don't use the full saturated player color as a solid fill — darken the bottom, lighten the top.
- Don't make the board feel digital or projected — it should feel like a physical object, not a UI element.

---

## Logo / Wordmark Specification ✅ Complete

When generating a Wahulo logo, these constraints apply:

**Text:** "WAHULO" — the game's name. Subtitle "Marble Mayham" is secondary.

**Typography feel:** Serif or slab-serif with slightly worn/pressed character — evokes a physical stamp or wood-block printing. High letter-spacing (~0.1–0.15em). Bold weight.

**Color:** Gold/amber gradient. Primary color: `#c8922a`. Lighter end: `#e8b84a`. Darker end: `#8a5a18`. Optionally: light text bevel/emboss effect.

**Background (if needed):** Dark warm brown `#1e160e` or transparent.

**Decorative elements (optional):** A marble or 4 marbles arranged symmetrically. The 4 player colors (red/green/yellow/blue) as small accent elements. A simple geometric board-like motif (cross or square with arms) — matches the actual game board shape.

**What to avoid:** Clip art, emojis, cartoon faces, photographic marble images, anything that looks like a digital game logo vs. a classic board game brand.

---

## Icon Specification ✅ Complete

**Purpose:** Browser tab favicon + mobile home screen bookmark.

**Size:** Design at 512×512, export at 512, 180, 32.

**Concept options (choose one):**
1. Single marble (one of the 4 player colors, or multi-colored) on a dark wood background
2. A 2×2 grid of 4 marbles in player colors (red/green/yellow/blue)
3. The "W" initial from the Wahulo wordmark on dark wood
4. Top-down view of the center hole of the board (a dark circle with subtle wood grain surround)

**Style:** Same lighting/material as the board and marbles. Wood border/frame. No hard flat outlines. Rounded square crop (the browser will mask it).

---

## Boot Splash Specification ✅ Complete

Displayed by the Godot engine for ~0.5–2 seconds after WASM loads, before the main game scene appears.

**Size:** 800×450 (16:9) or 800×600 (4:3). Godot will letterbox it.

**Content:** Game title "WAHULO" centered, subtitle "Marble Mayham" below. Optional: one or all 4 marbles arranged decoratively. Dark warm background (`#1e160e`).

**Style:** Same as the HTML loading screen already implemented. Should be a seamless visual transition — the HTML loading screen fades out and this appears momentarily before the game board loads.

**Format:** PNG (required by Godot boot splash).

---

## Open Graph / Social Preview Specification ✅ Complete

**Size:** 1200×630 PNG.

**Content:** Game title prominently, 4 marbles or a top-down board view, brief tagline ("A marble race for 4 players").

**Purpose:** Appears when someone shares wahulo.com on social media, iMessage, Slack, etc.

**Style:** Richer than the icon — room for the board environment, title treatment, and marble arrangement.

---

## In-Game Title Branding ✅ Complete

The game name uses the official wordmark SVG in all in-game title locations in `godot/scenes/Main.tscn`. Each title slot is a `TextureRect` wired to `res://assets/textures/wahulo_wordmark.svg`, and `godot/scripts/main.gd` re-applies this at runtime to enforce consistency.

| Location | Node path | Node type | Context |
|----------|-----------|-----------|---------|
| Side panel top | `Root/SidePanel/GameTitle` | `TextureRect` | Visible throughout all gameplay |
| Setup overlay header | `SetupOverlay/SetupPanel/SetupContent/BrandTitle` | `TextureRect` | Shown above "Game Setup" before each game |
| Win overlay header | `WinOverlay/WinPanel/WinContent/BrandTitle` | `TextureRect` | Shown above the winner announcement |

**Rendering behavior:** Titles use `STRETCH_KEEP_ASPECT_CENTERED` so the full wordmark is preserved across desktop and mobile panel widths.

---

## Atmosphere Reference Summary

If describing the game world to an image generation model:

> A top-down view of a wooden board game. The board is made of warm oak with visible wood grain — darker at the edges, lighter toward the center. It has a classic track with small carved circular positions, a cross-shaped path leading to a center hole, and four colored home areas in the corners (red, green, yellow, blue). The marbles are glass spheres with internal color, placed in the carved spots, catching light from above. The lighting is warm and ambient, like a table lamp. The board sits on a dark tabletop. The overall mood is cozy, tactile, classic.

---

*Last updated: 2026-05-31. All color values sourced from `godot/scripts/wahoo_board_view.gd`, `godot/scripts/main.gd`, `godot/assets/textures/board_wood.svg`, `godot/assets/textures/marble_gloss.svg`, `godot/build/web/index.html`, and `godot/scenes/Main.tscn`.*
