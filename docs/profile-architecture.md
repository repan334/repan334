# GitHub Profile Architecture

This document records the design logic behind the GitHub profile of **Reyy** (Reifan Putra Pratama). It keeps the profile consistent when the copy, projects, skills, or visual assets change later.

## 1. Positioning

The public identity is **Reyy - Junior Engineer**, supported by the line **Passionate about AI/ML Engineering**. The junior title communicates the current career level, while the About Me, current-work section, and Learning Map clearly distinguish completed practice from future learning. This keeps the profile ambitious without implying established production AI/ML experience.

Primary audiences:

1. Recruiters evaluating junior and internship candidates.
2. Developers considering a learning-focused collaboration.
3. AI/ML communities following a documented technical journey.

The copy follows three rules:

- Describe evidence before ambition.
- Treat learning tools as a roadmap, not proof of mastery.
- Show persistence through current work and project history instead of using self-promotional adjectives.

## 2. Information hierarchy

The README uses an evidence-first scroll story with visual interruptions:

| Order | Section | Purpose | Visitor question answered |
| --- | --- | --- | --- |
| 1 | Animated hero and action navigation | Establish technical direction and offer direct paths to work, stack, or contact | “Who is Reyy, and where should I click?” |
| 2 | Animated journey map | Compress biography into a three-stage software → data/UX → AI story | “Where has he been, and where is he going?” |
| 3 | Optional human story | Keep biography available without forcing every visitor through a paragraph | “What motivated this direction?” |
| 4 | Visual selected work | Show four projects with recognisable stack icons, a problem, and a focus | “What has he actually built?” |
| 5 | Proof of motion | Interrupt the page with current GitHub evidence after project claims | “Is this work still active?” |
| 6 | Languages and tools by purpose | Translate each technology into a beginner-friendly outcome | “What does he use Python, Flutter, or Postman for?” |
| 7 | Optional learning direction | Preserve roadmap context without letting future plans dominate the portfolio | “What is he learning next?” |
| 8 | Contribution trail | Finish the technical story with motion and consistency | “Does he keep showing up?” |
| 9 | Closing contact | Give recruiters and collaborators one clear next action | “How do I reach him?” |

## 3. Visual system

### Palette

| Token | Hex | Use |
| --- | --- | --- |
| Midnight canvas | `#050816` | Hero and card backgrounds |
| Raised navy | `#0B1026` | Badges and quiet surfaces |
| Grid navy | `#172554` | Low-contrast dotted canvas texture |
| Cyan signal | `#22D3EE` | Active data, primary highlight, Snake head |
| Violet direction | `#7C3AED` | Main accent and activity line |
| Soft violet | `#A78BFA` | Secondary nodes and labels |
| Cool white | `#E2E8F0` | Primary text inside generated cards |
| Muted slate | `#94A3B8` | Supporting text and secondary annotations |
| Indigo border | `#312E81` | Boundaries without bright visual noise |

The palette is applied consistently to the hero, contact badges, statistics, activity graph, and Snake. Decorative colors do not introduce additional meanings.

### Motion

Motion is limited to small data packets, orbit nodes, the journey-map route, and the contribution Snake. The hero contains no 3D objects, drop shadows, noisy particles, glow haze, or blurred transitions. The complete system stays visible in every frame so its first-frame preview is useful, labels never disappear while being read, and the loop has no flash or empty state.

### Typography

The identity, biography, skills, and project descriptions remain native HTML or Markdown. Only the six short architecture labels are baked into the GIF, where they function as visual annotations rather than unique biography. Equivalent meaning is preserved in the image alt text and the surrounding profile sections.

## 4. Skill representation logic

The profile deliberately avoids percentages and progress bars because they have no stable measurement. The primary stack is separated by what a visitor needs to understand:

1. **Languages** explain which kind of instruction or logic each language supplies.
2. **Frameworks** explain how mobile, web, backend, data, and AI products take shape.
3. **Workflow tools** explain how work is versioned, developed, shared, and tested.

Skill icons provide fast recognition, while adjacent plain-language copy explains practical use for non-developers. Future topics live inside a collapsed learning-direction panel so ambition does not visually compete with completed work. Technologies are not presented as equal proficiency.

## 5. Project selection logic

The four selected projects were requested by Reifan and verified against their public repository metadata:

- **Sasmita Lens** is identified as a fork/collaborative concept. Its simulated scanning interface is described clearly so UI exploration is not mistaken for a deployed AI model.
- **Library Management** demonstrates PHP, CSS, MySQL, and multi-role workflow practice.
- **Calculator** records mobile UI and input-logic practice in Dart/Flutter.
- **Bookshelf API** is framed as an early backend learning repository because its current public content is minimal.

Recent repositories, `Programming-with-Python` and `apk_prompt`, appear in the current-work section because public activity shows they better represent the present learning direction.

## 6. Dynamic components

| Component | Provider | Update model | Failure behavior |
| --- | --- | --- | --- |
| Overall stats | GitHub Stats Extended | Generated when requested | Alt text remains visible |
| Top languages | GitHub Stats Extended | Generated when requested | Copy does not depend on the card |
| Streak | GitHub Readme Streak Stats | Generated when requested | Section remains understandable without it |
| Profile views | Komarev counter | Updated on profile requests | Non-critical decoration only |
| Contribution Snake | Platane/snk GitHub Action | Daily and manual workflow | Alt text remains; first run creates output branch |

Dynamic statistics support the narrative but never carry unique biographical information. This prevents a third-party outage from removing essential profile content.

## 7. Asset strategy

The active hero pipeline uses:

- `assets/reyy-logo-source.png` — the source profile logo preserved without redesigning its geometry.
- `assets/reyy-ai-system-preview-v1.gif` — the approved, repository-owned animated hero used by the README.
- `assets/reyy-journey-map.svg` — the repository-owned animated introduction shown below the hero.
- `scripts/build-system-gif.ps1` — deterministic builder that recreates the GIF from the source logo.

The GIF is 1120×496 pixels with 30 frames, a 120 ms frame delay, and an infinite 3.6-second loop. Every frame shows the Reyy logo and six branches for Source Code, Data Preparation, Model Evaluation, Neural Networks, Linear Regression, and Classification; only the signal packets and orbit nodes move. The flat canvas uses the same Neural Midnight palette, rounded-card geometry, borders, and accents as the journey map, badges, and activity cards and does not rely on a third-party image host.

Free animation sources evaluated during research:

- [Pixabay: Brain, Mind, Technology](https://pixabay.com/gifs/brain-mind-technology-network-11343/) — 894×502 GIF under the Pixabay Content License.
- [LottieFiles: Deep Learning](https://lottiefiles.com/free-animation/deep-learning-B1ypd2GQXy) — compact 2D animation under the Lottie Simple License.
- [LottieFiles: Neural Network](https://lottiefiles.com/free-animation/neural-network-4avvDWNeEA) — downloadable as GIF or animated SVG under the Lottie Simple License.

These external assets were not embedded because they were generic, would add an external availability dependency, and did not combine Reyy's identity with the requested software and AI/ML architecture. The approved GIF is generated locally so its layout, timing, terminology, and color system stay under repository control.

## 8. Repository structure

```text
repan334/
├── README.md
├── assets/
│   ├── README.md
│   ├── reyy-logo-source.png
│   ├── reyy-ai-system-preview-v1.gif
│   ├── reyy-journey-map.svg
│   ├── neural-midnight-hero.png
│   └── neural-midnight-hero.svg
├── docs/
│   └── profile-architecture.md
├── scripts/
│   ├── build-hero.ps1
│   └── build-system-gif.ps1
└── .github/
    └── workflows/
        └── snake.yml
```

`README.md` is the profile itself. `assets/` contains profile-owned visual files; the older Neural Midnight PNG/SVG pair remains as an unused design reference. `docs/` explains future design decisions. `scripts/build-system-gif.ps1` rebuilds the active animated cover. The workflow publishes generated Snake files to an `output` branch so daily automation does not add commits to `main`.

## 9. Maintenance rules

When updating the profile:

1. Add a technology to the primary stack only after it has been used in a project or focused exercise.
2. Move a technology out of the collapsed learning direction only when a concrete project can support the change.
3. Keep no more than four projects in the main selected-project section.
4. Prefer current, original work over forks when a stronger AI/ML project becomes available.
5. Rewrite project descriptions around the problem, personal contribution, and evidence—not generic adjectives.
6. Keep the Neural Midnight palette unchanged across any new cards or assets.
7. Run `powershell -ExecutionPolicy Bypass -File scripts/build-system-gif.ps1` after changing the logo, card labels, timing, or hero layout.
8. Trigger the Snake workflow manually after the first push so the `output` branch and animation URLs exist immediately.
