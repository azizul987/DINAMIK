# Pixel Resources Pack — 100 animated game resources

100 pixel-art resource items for crafting, RPG, survival, idle and farming games. Every item has a static sprite and an 8-frame looping animation.

## Contents
| Path | What |
|---|---|
| `static/NNN_name.png` | 100 static sprites, 64×64, transparent |
| `anim/NNN_name_strip.png` | 8-frame animation strips, 512×64 (frame 64×64), seamless loop |
| `gif/NNN_name.gif` | ×2 GIF previews |
| `resources_atlas.png` + `.json` | all animations in one atlas (row = item, 8 columns = frames) |
| `resources.json` | id, name, category, description, file paths, atlas row |
| `index.html` | showcase page (open via any static server) |
| `preview/` | all 100 in one image / GIF |

## Categories (10 × 10)
Wood & Plants · Stone & Ores · Ingots · Gems · Magic · Food · Animal Materials · Crafting · Potions & Liquids · Tech

## Animations
Ores glint, ingots and gems shine, potions bubble, lava boils, fire / ice / lightning / shadow essences swirl, the gear turns, the spring bounces, the chip blinks, the battery charges, slime jiggles, food and materials gently bob with sparkles. Recommended speed: 8–12 fps.

```css
.item { width: 64px; height: 64px; background: url(anim/043_fire_essence_strip.png); animation: play .8s steps(8) infinite; image-rendering: pixelated; }
@keyframes play { to { background-position-x: -512px; } }
```
Scale only by whole numbers with nearest-neighbour filtering.

## License
Use in unlimited personal and commercial projects. Do not resell or redistribute the pack as an asset pack.

Sprites and animations were generated with PixelLab (pixel-art generative AI) and curated / color-corrected by hand.
