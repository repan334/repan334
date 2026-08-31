# Profile visual assets

## Active Reyy AI system hero

`reyy-logo-source.png` is the source profile logo. `reyy-ai-system-preview-v1.gif` is the approved 2D animated cover currently referenced by the root README.

The animation follows a fixed sequence: the logo appears, six architecture branches extend outward, the system cards become readable, data packets travel along the connections, and the composition fades before looping. The six cards represent Source Code, Data Preprocessing, Model Evaluation, Neural Networks, Linear Regression, and Classification + Categorical.

The asset is generated locally at 1120×496 pixels with 48 frames and an infinite loop. Its design stays within the Neural Midnight palette and intentionally excludes 3D perspective, shadows, blur, glow haze, and visual clutter.

To rebuild it after changing the logo, labels, timing, or layout:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-system-gif.ps1
```

## Interactive journey map

`reyy-journey-map.svg` is the compact visual introduction shown immediately after the hero. It replaces the previous biography-first opening with three scannable stages: building useful software, connecting data with UX, and growing toward applied AI.

The SVG is 1120×340 pixels and contains two lightweight motion cues: a moving dashed route and a travelling signal node. Its meaning is also available through SVG title/description elements and the README image alt text. It requires no JavaScript, keeping it compatible with GitHub's README renderer.

## Previous hero concept

`neural-midnight-hero.png` was generated with the built-in image generation tool as an original raster base for this GitHub profile. `neural-midnight-hero.svg` embeds that raster and adds the restrained vector motion used by the README.

Final generation prompt:

```text
Use case: stylized-concept
Asset type: wide GitHub profile README hero artwork
Primary request: create an original, polished 2D editorial technology illustration that represents a student beginning a serious journey toward AI and machine learning engineering
Scene/backdrop: full dark Neural Midnight canvas with a clean deep navy background
Subject: a precise side-profile human silhouette built from fine neural-network nodes and connecting paths, integrated with a compact flat terminal/code panel and subtle data-flow lines; communicate learning, experimentation, persistence, and intelligent systems
Style/medium: crisp high-resolution 2D vector-like editorial illustration with disciplined geometry and realistic technical structure; clean flat shapes and linework, not cartoonish
Composition/framing: very wide panoramic banner, balanced center composition, generous safe margins, visually readable at GitHub README width
Lighting/mood: restrained electric cyan and violet accents on deep navy; calm, focused, modern, technical
Color palette: #050816, #0B1026, #22D3EE, #7C3AED, #A78BFA, small restrained #E2E8F0 highlights
Constraints: no text, no letters, no numbers, no logos, no trademarks, no watermark, no gradients that create banding, no shadows, no glow haze, no blur, no noise, no clutter, no 3D objects, no isometric perspective; perfectly clean edges and consistent 2D visual language
Avoid: robots, humanoid androids, stock cyberpunk imagery, glossy effects, excessive neon, floating UI clutter, overconfidence or heroic pose
```

The SVG is no longer referenced by the root README. To rebuild this archived concept after replacing the PNG:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-hero.ps1
```
